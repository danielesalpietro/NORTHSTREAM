"""
NORTHSTREAM Stream Context Agent
---------------------------------
Consumes live CDC events from Kafka (produced by Debezium from Postgres),
embeds them with an Ollama embedding model, and indexes them in Qdrant.

Exposes:
  GET  /health           -> service + buffer status
  GET  /events            -> last N raw stream events seen
  POST /chat               -> answer a question grounded in recent stream data
  POST /compare             -> answer the SAME question with and without
                                stream context, side by side (the actual demo)

The point of /compare is to make visible, in one call, how much a small
local model improves when it is given fresh, relevant, structured context
pulled straight from the live data stream instead of answering from
parametric memory alone.
"""

import json
import os
import threading
import time
from collections import deque
from datetime import datetime, timezone

import requests
from fastapi import FastAPI
from pydantic import BaseModel
from kafka import KafkaConsumer
from qdrant_client import QdrantClient
from qdrant_client.http import models as qmodels

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka:9092")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333")
CHAT_MODEL = os.getenv("OLLAMA_CHAT_MODEL", "llama3.2:3b")
EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
TOPIC_PATTERN = os.getenv("KAFKA_TOPIC_PATTERN", r"^northstream\..*")
COLLECTION = "stream_events"
MAX_BUFFER = 500

app = FastAPI(title="NORTHSTREAM Stream Context Agent")

recent_events = deque(maxlen=MAX_BUFFER)
qdrant = QdrantClient(url=QDRANT_URL)
_collection_ready = False
_point_id_lock = threading.Lock()
_point_id = 0


def ensure_collection(vector_size: int):
    global _collection_ready
    if _collection_ready:
        return
    existing = [c.name for c in qdrant.get_collections().collections]
    if COLLECTION not in existing:
        qdrant.create_collection(
            collection_name=COLLECTION,
            vectors_config=qmodels.VectorParams(
                size=vector_size, distance=qmodels.Distance.COSINE
            ),
        )
    _collection_ready = True


def embed_text(text: str):
    resp = requests.post(
        f"{OLLAMA_BASE_URL}/api/embeddings",
        json={"model": EMBED_MODEL, "prompt": text},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["embedding"]


def event_to_text(topic: str, payload: dict) -> str:
    op_map = {"c": "INSERT", "u": "UPDATE", "d": "DELETE", "r": "SNAPSHOT"}
    op = op_map.get(payload.get("op", "?"), payload.get("op", "?"))
    after = payload.get("after") or {}
    before = payload.get("before") or {}
    ts = payload.get("ts_ms")
    data = after if after else before
    return f"[{topic}] {op} ts={ts} data={json.dumps(data, default=str)}"


def next_point_id() -> int:
    global _point_id
    with _point_id_lock:
        _point_id += 1
        return _point_id


def consume_loop():
    consumer = None
    while consumer is None:
        try:
            consumer = KafkaConsumer(
                bootstrap_servers=KAFKA_BOOTSTRAP,
                auto_offset_reset="latest",
                value_deserializer=lambda v: json.loads(v.decode("utf-8")) if v else None,
                consumer_timeout_ms=1000,
            )
            consumer.subscribe(pattern=TOPIC_PATTERN)
            print("Connected to Kafka, subscribed with pattern:", TOPIC_PATTERN)
        except Exception as e:
            print("Kafka not ready yet, retrying:", e)
            time.sleep(5)
            consumer = None

    while True:
        try:
            for msg in consumer:
                if msg.value is None:
                    continue
                payload = msg.value.get("payload", msg.value)
                if not isinstance(payload, dict):
                    continue
                text = event_to_text(msg.topic, payload)
                recent_events.append(
                    {
                        "topic": msg.topic,
                        "text": text,
                        "at": datetime.now(timezone.utc).isoformat(),
                    }
                )
                try:
                    vector = embed_text(text)
                    ensure_collection(len(vector))
                    qdrant.upsert(
                        collection_name=COLLECTION,
                        points=[
                            qmodels.PointStruct(
                                id=next_point_id(),
                                vector=vector,
                                payload={"text": text, "topic": msg.topic},
                            )
                        ],
                    )
                except Exception as e:
                    print("embedding/upsert failed:", e)
        except Exception as e:
            print("consumer loop error:", e)
            time.sleep(2)


threading.Thread(target=consume_loop, daemon=True).start()


class ChatRequest(BaseModel):
    question: str
    top_k: int = 5


def search_context(question: str, top_k: int):
    try:
        vector = embed_text(question)
        ensure_collection(len(vector))
        hits = qdrant.search(collection_name=COLLECTION, query_vector=vector, limit=top_k)
        if hits:
            return [h.payload["text"] for h in hits]
    except Exception as e:
        print("semantic search failed, falling back to recent buffer:", e)
    # fallback: just use the most recent raw events
    return [e["text"] for e in list(recent_events)[-top_k:]]


def call_ollama(prompt: str) -> str:
    resp = requests.post(
        f"{OLLAMA_BASE_URL}/api/generate",
        json={"model": CHAT_MODEL, "prompt": prompt, "stream": False},
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json().get("response", "").strip()


def build_grounded_prompt(question: str, context: list) -> str:
    context_block = "\n".join(context) if context else "(no relevant stream data found)"
    return (
        "You are a data assistant. Answer the question using ONLY the real-time "
        "stream events listed below as context. If the context does not contain "
        "the answer, say explicitly that the data stream does not show it - do "
        "not guess.\n\n"
        f"Context (recent live stream events):\n{context_block}\n\n"
        f"Question: {question}\nAnswer:"
    )


@app.get("/health")
def health():
    return {
        "status": "ok",
        "buffered_events": len(recent_events),
        "chat_model": CHAT_MODEL,
        "embed_model": EMBED_MODEL,
    }


@app.get("/events")
def events(limit: int = 20):
    return list(recent_events)[-limit:]


@app.post("/chat")
def chat(req: ChatRequest):
    context = search_context(req.question, req.top_k)
    answer = call_ollama(build_grounded_prompt(req.question, context))
    return {"answer": answer, "context_used": context}


@app.post("/compare")
def compare(req: ChatRequest):
    """The actual demo: same small model, same question, with vs without
    grounding in the live stream. Run this and read both answers side by
    side."""
    baseline_answer = call_ollama(f"Question: {req.question}\nAnswer:")

    context = search_context(req.question, req.top_k)
    grounded_answer = call_ollama(build_grounded_prompt(req.question, context))

    return {
        "question": req.question,
        "model": CHAT_MODEL,
        "without_stream_context": baseline_answer,
        "with_stream_context": grounded_answer,
        "context_used": context,
    }
