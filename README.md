# NORTHSTREAM

**Open-source real-time governed data platform simulator for IBM watsonx.data + Confluent concepts.**

NORTHSTREAM is a local, Docker Compose-based lab designed to simulate the core building blocks of a modern real-time, governed, AI-ready data platform.

It is inspired by the architectural concepts behind:

- real-time data streaming
- change data capture (CDC)
- schema governance
- stream processing
- lakehouse-style data foundations
- metadata management and data intelligence
- local LLM-based interaction with data

> NORTHSTREAM is not a production platform. It is a technical playground for learning, presales storytelling, demos, architecture validation, and internal enablement.

> **What is actually wired today.** One data path runs end to end:
> PostgreSQL → Debezium CDC → Kafka → Stream Context Agent → Qdrant → local LLM.
> Flink, Apicurio, MinIO, Trino and OpenMetadata start with the stack and are
> useful to show and discuss, but nothing writes to them or reads from them
> yet: they are available extensions, not steps of the current flow. The
> [Layer status](#layer-status) table below says which is which, service by
> service. Work in progress is tracked in
> [`docs/piano_ricovero.md`](docs/piano_ricovero.md) (in Italian).

---

## Why NORTHSTREAM?

Modern data platforms are moving from batch-oriented integration to real-time, governed, AI-ready data flows.

NORTHSTREAM demonstrates how operational data can move from transactional systems into an event streaming backbone, be processed in real time, stored in a lakehouse-style foundation, governed through metadata and catalog services, and finally exposed to a local AI/chat interface.

The goal is to provide a compact open-source simulator for explaining concepts such as:

- data in motion
- data products
- CDC-based integration
- real-time data pipelines
- schema evolution
- stream processing
- AI-ready data
- governed data foundations
- chat with data

---

## High-Level Architecture

```text
NORTHSTREAM
|
+-- Data in Motion / Confluent-like Layer
|   +-- Apache Kafka
|   +-- Kafka UI
|   +-- Schema Registry compatible service
|
+-- Data Integration / CDC Layer
|   +-- PostgreSQL operational source
|   +-- Debezium Kafka Connect
|
+-- Stream Processing Layer
|   +-- Apache Flink JobManager
|   +-- Apache Flink TaskManager
|
+-- Lakehouse Foundation Layer
|   +-- MinIO S3-compatible object storage
|   +-- Trino SQL query engine
|
+-- Data Intelligence / Governance Layer
|   +-- OpenMetadata
|   +-- PostgreSQL metadata database
|   +-- Elasticsearch
|
+-- AI / Chat with Data Layer
|   +-- Ollama local LLM runtime
|   +-- Open WebUI chat interface
|
+-- Stream Context Agent Layer (addon)
    +-- Qdrant vector store
    +-- FastAPI stream-agent (Kafka consumer + RAG over live events)
    +-- Data generator (continuous synthetic orders/sensor events)
```

---

## Data Flow Storyline

This is the path an event actually takes today, from an `INSERT` to a grounded
answer:

```text
PostgreSQL (operational source)
   |
   | CDC with Debezium / Kafka Connect
   v
Apache Kafka  --------> Kafka UI (topics, messages, connectors)
   |
   | consumed by the Stream Context Agent (addon)
   v
Qdrant (embeddings of live events)
   |
   | retrieved as context at question time
   v
Ollama (small local LLM) + Open WebUI
Grounded answers about what just happened in the stream
```

A typical demo scenario is:

1. Insert or update records in the PostgreSQL operational database (the
   `data-generator` does this continuously).
2. Capture changes through Debezium CDC.
3. Publish events into Kafka topics.
4. Observe topics and messages from Kafka UI.
5. Watch the Stream Context Agent consume, embed and index those events.
6. Ask the same question with and without stream context, and compare the two
   answers side by side.

### Layer status

The stack starts more services than the flow above uses. They are worth
showing — they make the architecture discussion concrete — but the README
would be lying if it described them as part of the pipeline:

| Layer | Service | Status |
|---|---|---|
| Data integration / CDC | PostgreSQL, Debezium Connect | **Wired** — the source of every event |
| Data in motion | Kafka, Kafka UI | **Wired** — the backbone the agent consumes |
| AI / chat with data | Ollama, Open WebUI | **Wired** — answers the demo question |
| Stream Context Agent (addon) | qdrant, stream-agent, data-generator | **Wired** — the RAG loop over live events |
| Schema governance | Apicurio Registry | **Not wired** — Debezium uses `JsonConverter` with schemas disabled, so no schema is ever registered |
| Stream processing | Flink JobManager, TaskManager | **Not wired** — the cluster runs, no job is submitted by this repository |
| Lakehouse foundation | MinIO, Trino | **Not wired** — the buckets are created and stay empty; Trino starts without catalogs |
| Governance | OpenMetadata, Elasticsearch | **Not wired** — the catalog runs empty, no ingestion is configured |

Connecting these layers one at a time, each with a working demo as the
definition of done, is the subject of the [Roadmap](#roadmap).

---

## Included Services

| Layer | Service | Purpose | Default URL / Port |
|---|---|---|---|
| Landing Page | landing-page | Overview page linking to every service in the stack | [NORTHSTREAM Landing](http://localhost:8000) |
| Streaming | Kafka | Event streaming backbone | in-network only: `kafka:9092` (see note below) |
| Streaming UI | Kafka UI | Kafka topics, consumers, connectors visibility | [Kafka UI](http://localhost:8088) |
| Schema Governance | Apicurio Registry | Schema registry compatible service | [Schema Registry](http://localhost:8081) |
| Operational Source | PostgreSQL | Source transactional database | `localhost:5432` |
| DB Web Client | Adminer | Web SQL client for the PostgreSQL source | [Adminer](http://localhost:8090) |
| CDC / Integration | Debezium Connect | Kafka Connect runtime for CDC pipelines | [Kafka Connect](http://localhost:8083) |
| Stream Processing | Apache Flink | Real-time stream processing | [Flink UI](http://localhost:8082) |
| Object Storage | MinIO | S3-compatible lakehouse storage | [MinIO Console](http://localhost:9001) |
| Query Engine | Trino | Distributed SQL query engine | [Trino UI](http://localhost:8080) |
| Governance | OpenMetadata | Data catalog, governance and metadata platform | [OpenMetadata](http://localhost:8585) |
| Search Backend | Elasticsearch | OpenMetadata search backend | [Elasticsearch](http://localhost:9200) |
| Local LLM | Ollama | Local LLM runtime | [Ollama API](http://localhost:11434) |
| Chat UI | Open WebUI | Web interface for local LLM interaction | [NORTHSTREAM Chat](http://localhost:3000) |
| Vector Store | Qdrant | Semantic index over live stream events | [Qdrant](http://localhost:6333) |
| Stream Context Agent | stream-agent | Grounds a small Ollama model in real-time Kafka/CDC events | [Stream Agent API](http://localhost:8500) |
| Synthetic Data | data-generator | Continuously produces realistic orders and sensor events | (no UI, writes to PostgreSQL) |

> **Note on the Kafka endpoint.** The broker advertises `PLAINTEXT://kafka:9092`,
> a name that only resolves inside the Docker network. Port 9092 is published,
> but a client on the host bootstraps successfully and then receives metadata
> pointing at `kafka:9092`, which it cannot reach — so host tools such as
> `kcat` or `kafka-console-consumer` do not work against it today. Consume from
> inside a container (`docker exec northstream-kafka kafka-console-consumer.sh
> --bootstrap-server kafka:9092 --topic northstream.public.sensor_readings`) or
> use Kafka UI. A second, host-advertised listener is planned; the behaviour is
> pinned by test `T0.6` in [`bench/t0/`](bench/).

---

## Prerequisites

- Docker Engine or Docker Desktop
- Docker Compose v2

Pick the tier that matches your machine. All three run the full base stack
plus the Stream Context Agent addon — the difference is model size and
response speed.

| Tier | RAM | vCPU | Disk | GPU | Suggested Granite models |
|---|---|---|---|---|---|
| **Minimal** | 16 GB | 4 | 30 GB free | not required | `granite4:350m` + `granite-embedding:30m` |
| **Recommended** | 32 GB | 8 | 50 GB free | not required | `granite4:1b` + `granite-embedding:30m` |
| **Optimal** | 32 GB+ | 8+ | 80 GB+ free | 8+ GB VRAM (e.g. RTX 4060/5080) | `granite4:3b` or `granite4:7b-a1b-h` + `granite-embedding:278m` |

Minimal is enough to see every layer of the pipeline working end to end;
below 16 GB RAM, Elasticsearch and OpenMetadata alone will struggle to start.
A GPU is never required, but it makes chat responses noticeably faster and
lets you comfortably run the larger Granite variants.

### Per-tier examples

[`examples/`](examples/) has one folder per tier (`minimal/`, `recommended/`,
`optimal/`), each with two ready-to-copy files:

- **`.wslconfig`** — Windows/WSL2 memory and CPU limits for that tier
- **`.env`** — selects `OLLAMA_CHAT_MODEL` / `OLLAMA_EMBED_MODEL` for that
  tier; copied to the repository root, it is picked up automatically by
  `docker compose`

```powershell
# Windows: apply WSL2 limits (adjust the tier folder name as needed)
copy examples\recommended\.wslconfig $env:UserProfile\.wslconfig
wsl --shutdown
# restart Docker Desktop afterwards

# Select the models for that tier
copy examples\recommended\.env .env
```

```bash
# Linux/macOS: select the models for that tier
cp examples/recommended/.env .env
```

Without a `.env` file, the stack defaults to the Recommended tier
(`granite4:1b` / `granite-embedding:30m`). The repository ships
[`.env.example`](.env.example) as a template — `.env` itself is git-ignored, so
switching tier locally never shows up as a repository change:

```bash
cp .env.example .env
```

### GPU passthrough (optional)

If you have an NVIDIA GPU with enough VRAM (see the table above), start the
addon with GPU passthrough enabled instead of the CPU-only default:

```powershell
.\start-addon.ps1 -Gpu
```

```bash
./start-addon.sh --gpu
```

This adds [`docker-compose.gpu.yml`](docker-compose.gpu.yml), which reserves
the GPU for the `ollama` service. It requires a current NVIDIA driver on the
host — WSL2 GPU support is enabled automatically by the driver, no extra
Docker Desktop setting is needed.

---

## Quick Start

Clone the repository:

```bash
git clone https://github.com/danielesalpietro/NORTHSTREAM.git
cd NORTHSTREAM
```

Start the platform:

```bash
docker compose -f docker-compose-northstream-ai.yml up -d
```

Check service status:

```bash
docker compose -f docker-compose-northstream-ai.yml ps
```

Open the landing page for an overview and links to every service:

[http://localhost:8000](http://localhost:8000)

Stop the platform:

```bash
docker compose -f docker-compose-northstream-ai.yml down
```

Stop the platform and remove persistent volumes:

```bash
docker compose -f docker-compose-northstream-ai.yml down -v
```

---

## Stream Context Agent (addon)

This addon closes the gap described below in "What NORTHSTREAM Does Not Yet
Provide". It demonstrates that a small, local LLM answers accurately when it
is grounded in fresh, high-quality stream data, and answers generically (or
makes things up) when it is not.

It adds three services on top of the base stack:

- **data-generator** — continuously writes realistic orders and sensor
  readings into PostgreSQL, so there is always fresh data flowing through CDC
- **qdrant** — vector store indexing live Kafka events for semantic retrieval
- **stream-agent** — a FastAPI service that consumes Kafka, embeds events
  with Ollama, retrieves relevant context from Qdrant, and answers questions
  through a small local model

Start it alongside the base stack:

```powershell
.\start-addon.ps1
```

```bash
./start-addon.sh
```

(equivalent to `docker compose -f docker-compose-northstream-ai.yml -f docker-compose.addon.yml up -d --build`; add `-Gpu` / `--gpu` for GPU passthrough)

Register the Debezium CDC connector:

```powershell
.\register-connector.ps1
```

```bash
./register-connector.sh
```

Then restart the agent, so it picks up the topics the connector just created:

```bash
docker restart northstream-stream-agent
```

This step is not optional bookkeeping. The agent subscribes to Kafka by topic
pattern at startup and its client refreshes cluster metadata only every five
minutes, so topics created afterwards — which is exactly what registering the
connector does — stay invisible to it until that window expires. Without the
restart, `/events` returns nothing and `/health` reports `buffered_events: 0`
for several minutes even though CDC is working (measured: 4 min 46 s). A proper
fix is planned; the behaviour is tracked as finding A-8 in
[`docs/review_tecnica.md`](docs/review_tecnica.md).

Pull the small models used by the agent (IBM Granite, open-source):

```bash
docker exec -it northstream-ollama ollama pull granite4:1b
docker exec -it northstream-ollama ollama pull granite-embedding:30m
```

### Demo via command line (batch)

Run the actual demo — same question, with and without live stream context:

```powershell
.\demo-compare.ps1
```

```bash
./demo-compare.sh
```

Both scripts accept an optional custom question as the first argument, and
are equivalent to:

```bash
curl -X POST http://localhost:8500/compare \
  -H "Content-Type: application/json" \
  -d '{"question": "Are there any recent sensor anomalies at Plant-B?"}'
```

Typical response:

- `without_stream_context` → the model answers generically or makes things
  up, because it has no real information about "Plant-B" today.
- `with_stream_context` → the model cites the actual values that just arrived
  from the stream (temperature, vibration, whether it's an anomaly), because
  you passed them in as context retrieved from Qdrant.

### Demo via Web GUI (Open WebUI)

The same comparison can be run entirely from [Open WebUI](http://localhost:3000)
instead of the command line, which is more convenient for live demos and
workshops.

`stream-agent` exposes an OpenAI-compatible surface (`/v1/models`,
`/v1/chat/completions`) purely so Open WebUI can treat it as just another
chat model, grounded in live stream context, side by side with the raw
Ollama model it already talks to natively.

1. Open [http://localhost:3000](http://localhost:3000) and sign in (or create
   the local admin account on first launch).
2. Go to **Admin Panel → Settings → Connections**, add an **OpenAI API**
   connection with:
   - **API Base URL**: `http://stream-agent:8500/v1`
   - **API Key**: any non-empty placeholder (e.g. `northstream`) — the
     endpoint doesn't validate it, Open WebUI just requires the field filled
   - Save. A model named `northstream-grounded` now shows up in the model
     picker, next to the native Granite models.
3. For a clean baseline, open **Workspace → Models**, edit the plain
   `granite4:1b` model, and uncheck everything under **Builtin Tools**
   (Calendario, Memoria, Knowledge Base, etc.). Otherwise the model may try
   to answer by calling an unrelated built-in tool (e.g. searching the
   calendar for "Plant-B") instead of answering — or not answering — from its
   own knowledge.
4. Start a **new chat** with `granite4:1b` and ask the demo question — this
   is the ungrounded baseline.
5. Start another **new chat** with `northstream-grounded` and ask the exact
   same question — this one answers using real events retrieved from Qdrant.

Always use a fresh chat for each side of the comparison: reusing a thread
lets the model quote its own earlier (possibly wrong) answer from history
instead of actually reasoning about the question again.

Full step-by-step walkthrough: [`docs/demo-script.md`](docs/demo-script.md).

---

## Recommended Small LLMs

For a lightweight local lab, start with small models:

```bash
docker exec -it northstream-ollama ollama pull llama3.2:3b
docker exec -it northstream-ollama ollama pull qwen2.5:3b
docker exec -it northstream-ollama ollama pull phi3:mini
```

For a more capable environment, if hardware allows:

```bash
docker exec -it northstream-ollama ollama pull mistral:7b
docker exec -it northstream-ollama ollama pull llama3.1:8b
```

### IBM Granite (open-source, watsonx-aligned)

IBM's [Granite](https://www.ibm.com/granite) models are the open-source (Apache 2.0)
foundation models behind watsonx.ai, and are a natural fit for a
watsonx-inspired lab like NORTHSTREAM. Sizes below are as published on
[Ollama](https://ollama.com/library/granite4):

| Tag | Parameters | Download size | Tier |
|---|---|---|---|
| `granite4:350m` | 350M | 708 MB | Minimal |
| `granite4:1b` | 1B | 3.3 GB | Recommended |
| `granite4:3b` (`micro`) | 3B | 2.1 GB | Optimal (CPU-friendly) |
| `granite4:7b-a1b-h` (`tiny-h`, MoE) | 7B total / ~1B active | 4.2 GB | Optimal (GPU) |
| `granite4:32b-a9b-h` (`small-h`, MoE) | 32B total / ~9B active | 19 GB | beyond Optimal, needs 16 GB+ VRAM |

```bash
docker exec -it northstream-ollama ollama pull granite4:1b
```

IBM also publishes [`granite-embedding`](https://ollama.com/library/granite-embedding),
a native alternative to `nomic-embed-text` for the Stream Context Agent addon:

| Tag | Download size | Language | Tier |
|---|---|---|---|
| `granite-embedding:30m` | 63 MB | English only | Minimal / Recommended |
| `granite-embedding:278m` | 563 MB | multilingual | Optimal |

```bash
docker exec -it northstream-ollama ollama pull granite-embedding:30m
```

To use Granite in the Stream Context Agent, set `OLLAMA_CHAT_MODEL` and
`OLLAMA_EMBED_MODEL` accordingly in `docker-compose.addon.yml`.

Open the chat interface:

[NORTHSTREAM Chat](http://localhost:3000)

On first launch, Open WebUI will ask you to create a local admin account.

---

## Default Credentials

### PostgreSQL Source Database

```text
Host: localhost
Port: 5432
Database: sales
User: demo
Password: demo
```

Browse it from a browser via [Adminer](http://localhost:8090) — System:
PostgreSQL, Server: `postgres`, same user/password/database as above.

### MinIO

```text
Console: http://localhost:9001
User: admin
Password: Password123!
```

### OpenMetadata Database

```text
Database: openmetadata_db
User: openmetadata
Password: openmetadata
```

---

## MinIO Buckets

The compose file includes a helper container that creates the following buckets:

```text
lakehouse
raw-events
curated-data
```

These buckets represent a simplified data lakehouse layout. They are created
empty and stay empty: as the [Layer status](#layer-status) table says, nothing
in the current pipeline writes to object storage yet.

---

## What NORTHSTREAM Demonstrates

NORTHSTREAM is designed to support technical and presales conversations around:

- real-time data integration
- CDC from operational databases
- event streaming platforms
- Kafka topic governance
- schema compatibility
- stream processing patterns
- data lakehouse ingestion
- metadata management
- data cataloging
- lineage and governance concepts
- local AI assistants for data exploration

---

## What NORTHSTREAM Does Not Yet Provide

The base stack alone does not implement a complete end-to-end semantic "chat
with data" experience. It includes a local LLM runtime, a web chat
interface, SQL and metadata services, and streaming/lakehouse components,
but an additional application layer is required to connect the LLM to data
sources in a controlled way.

The **Stream Context Agent addon** (see above) implements the fourth item
below. The others remain open for future work:

1. **SQL Assistant** *(not yet implemented)*
   A service that lets the LLM generate and execute SQL queries through Trino.

2. **RAG Assistant** *(not yet implemented)*
   A vector database and document ingestion pipeline for retrieval-augmented generation over documents.

3. **Data Governance Agent** *(not yet implemented)*
   An assistant that can query OpenMetadata, explain lineage, inspect schemas and describe data assets.

4. **Streaming Data Agent** *(implemented by the addon)*
   An assistant that inspects Kafka/CDC events in real time and answers
   questions grounded in them, using Qdrant for retrieval and a small Ollama
   model for generation. See `docker-compose.addon.yml`, `stream-agent/` and
   `docs/demo-script.md`.

---

## Repository Layout

What the repository actually contains:

```text
northstream/
|
+-- docker-compose-northstream-ai.yml
+-- docker-compose.addon.yml
+-- docker-compose.gpu.yml
+-- README.md
+-- CHANGELOG.md
+-- LICENSE
+-- index.html
+-- dashboard.html
+-- start-addon.sh
+-- start-addon.ps1
+-- register-connector.sh
+-- register-connector.ps1
+-- demo-compare.sh
+-- demo-compare.ps1
+-- .env.example
|
+-- init/
|   +-- postgres/
|       +-- 001-init-sales-db.sql
|
+-- connectors/
|   +-- postgres-source-connector.json
|
+-- stream-agent/
|   +-- Dockerfile
|   +-- requirements.txt
|   +-- app.py
|
+-- data-generator/
|   +-- Dockerfile
|   +-- requirements.txt
|   +-- generate_events.py
|
+-- bench/
|   +-- README.md
|   +-- t0/
|   +-- ci/
|
+-- docs/
|   +-- demo-script.md
|   +-- piano_ricovero.md
|   +-- review_tecnica.md
|   +-- logbook/
|
+-- examples/
    +-- minimal/
    +-- recommended/
    +-- optimal/
```

Every path above is checked against the filesystem by test `T0.12`
([`bench/t0/lib/doc_truth.py`](bench/t0/lib/doc_truth.py)), which runs on every
push: this list cannot drift from reality without turning CI red.

---

## Demo Narrative

A concise demo narrative:

> NORTHSTREAM shows how operational data can become real-time and AI-ready.  
> It starts with transactional data in PostgreSQL, captures changes through Debezium, streams them through Kafka, and feeds them — via the Stream Context Agent addon — to a small local LLM that answers questions grounded in live stream events rather than from static or absent context. The lakehouse, stream-processing and governance layers are present in the stack as the next conversations to have, not as steps this pipeline already takes.

---

## Positioning

NORTHSTREAM can be used as:

- a learning lab
- a presales demo environment
- an architecture discussion starter
- an internal enablement tool
- a lightweight data platform simulator
- a sandbox for real-time data and AI-ready data concepts

It is especially useful when explaining the difference between:

- traditional batch integration
- event-driven integration
- real-time data products
- governed data platforms
- AI-ready data foundations

---

## Roadmap

Implemented by the Stream Context Agent addon:

- [x] Add PostgreSQL demo schema and sample data
- [x] Add Debezium connector bootstrap script
- [x] Add Qdrant vector database
- [x] Add FastAPI-based Data Assistant service (stream-agent)
- [x] Add demo scripts for customer-facing workshops

Still open:

- [ ] Add Trino catalogs for PostgreSQL and MinIO
- [ ] Add Iceberg support
- [ ] Add Prometheus and Grafana observability
- [ ] Add OpenMetadata ingestion examples
- [ ] Add Kubernetes / OpenShift deployment manifests
- [ ] Add SQL Assistant (LLM-generated queries through Trino)
- [ ] Add Data Governance Agent (LLM over OpenMetadata lineage/schemas)

---

## Security Notes

This project uses simple default credentials and plaintext communication for local testing only.

Do not use this configuration in production.

Before adapting it to a real environment, review at least:

- authentication
- authorization
- TLS encryption
- secret management
- network segmentation
- resource limits
- backup and restore
- data retention
- audit logging

---

## License

NORTHSTREAM is released under the **MIT License** — see [`LICENSE`](LICENSE)
for the full text.

---

## Disclaimer

NORTHSTREAM is an independent open-source lab concept. It is not affiliated with, endorsed by or certified by IBM, Confluent, Apache Software Foundation, OpenMetadata, Ollama, Open WebUI, Trino, MinIO, Debezium or any other vendor or open-source project mentioned in this repository.

All product names, trademarks and registered trademarks are property of their respective owners.
