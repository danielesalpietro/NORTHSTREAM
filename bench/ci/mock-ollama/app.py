"""Deterministic Ollama stand-in for CI.

It answers the two endpoints the stream-agent uses, with no model and no GPU:

  POST /api/embeddings  -> a unit vector derived from the SHA-256 of the text,
                           so the same text always yields the same vector
  POST /api/generate    -> an echo of the prompt's context block

This exercises the pipeline (CDC -> Kafka -> agent -> Qdrant -> answer), never
the model. Any test relying on it is testing plumbing, not answer quality.
"""

import hashlib
import json
import struct
from http.server import BaseHTTPRequestHandler, HTTPServer

DIM = 384  # matches granite-embedding:30m, so vector sizes stay realistic


def deterministic_vector(text: str) -> list[float]:
    digest = hashlib.sha256(text.encode("utf-8")).digest()
    values = []
    while len(values) < DIM:
        digest = hashlib.sha256(digest).digest()
        for i in range(0, len(digest), 4):
            if len(values) == DIM:
                break
            values.append(struct.unpack(">I", digest[i : i + 4])[0] / 2**32 - 0.5)
    norm = sum(v * v for v in values) ** 0.5 or 1.0
    return [v / norm for v in values]


class Handler(BaseHTTPRequestHandler):
    def _reply(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - name imposed by BaseHTTPRequestHandler
        if self.path.startswith("/api/tags"):
            self._reply({"models": [{"name": "mock-ollama", "model": "mock-ollama"}]})
        elif self.path.startswith("/api/version"):
            self._reply({"version": "mock"})
        else:
            self._reply({"status": "ok", "mock": True})

    def do_POST(self) -> None:  # noqa: N802 - name imposed by BaseHTTPRequestHandler
        length = int(self.headers.get("Content-Length", 0))
        try:
            request = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._reply({"error": "invalid json"}, status=400)
            return

        if self.path.startswith("/api/embeddings") or self.path.startswith("/api/embed"):
            text = request.get("prompt") or request.get("input") or ""
            if isinstance(text, list):
                text = " ".join(map(str, text))
            self._reply({"embedding": deterministic_vector(text)})
        elif self.path.startswith("/api/generate") or self.path.startswith("/api/chat"):
            prompt = request.get("prompt") or ""
            context = prompt.split("Context (recent live stream events):", 1)[-1]
            self._reply({"response": f"[mock-ollama echo] {context.strip()[:2000]}", "done": True})
        else:
            self._reply({"error": f"unhandled path {self.path}"}, status=404)

    def log_message(self, fmt: str, *args) -> None:
        print("mock-ollama:", fmt % args, flush=True)


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 11434), Handler).serve_forever()
