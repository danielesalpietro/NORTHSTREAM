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

```text
PostgreSQL
   |
   | CDC with Debezium / Kafka Connect
   v
Apache Kafka
   |
   +--> Schema Registry
   |
   +--> Apache Flink for stream processing
   |
   +--> MinIO for lakehouse-style object storage
   |
   +--> Trino for SQL access
   |
   +--> OpenMetadata for catalog, governance and lineage
   |
   +--> Stream Context Agent (addon): embeds live events with Ollama
   |    and indexes them in Qdrant for retrieval-augmented answers
   |
   v
Ollama + Open WebUI
Local AI assistant / chat interface
```

A typical demo scenario is:

1. Insert or update records in the PostgreSQL operational database.
2. Capture changes through Debezium CDC.
3. Publish events into Kafka topics.
4. Observe topics and messages from Kafka UI.
5. Process or enrich event streams with Flink.
6. Persist raw or curated data into MinIO.
7. Query data with Trino.
8. Register and document assets in OpenMetadata.
9. Use Ollama and Open WebUI as the local AI interaction layer.
10. Use the Stream Context Agent to ground a small local LLM in live stream
    data and compare grounded vs. ungrounded answers.

---

## Included Services

| Layer | Service | Purpose | Default URL / Port |
|---|---|---|---|
| Streaming | Kafka | Event streaming backbone | `localhost:9092` |
| Streaming UI | Kafka UI | Kafka topics, consumers, connectors visibility | [Kafka UI](http://localhost:8088) |
| Schema Governance | Apicurio Registry | Schema registry compatible service | [Schema Registry](http://localhost:8081) |
| Operational Source | PostgreSQL | Source transactional database | `localhost:5432` |
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

---

## Prerequisites

- Docker Engine or Docker Desktop
- Docker Compose v2
- At least 16 GB RAM for a reduced lab
- 32 GB RAM recommended
- 8 vCPU recommended
- 50+ GB free disk space recommended

For larger local LLMs, a GPU-enabled environment is recommended, but not required for smaller models.

---

## Quick Start

Clone the repository:

```bash
git clone <your-repository-url>
cd northstream
```

Start the platform:

```bash
docker compose -f docker-compose-northstream-ai.yml up -d
```

Check service status:

```bash
docker compose -f docker-compose-northstream-ai.yml ps
```

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

```bash
docker compose \
  -f docker-compose-northstream-ai.yml \
  -f docker-compose.addon.yml \
  up -d --build
```

Register the Debezium CDC connector:

```bash
curl -X POST -H "Content-Type: application/json" \
  --data @connectors/postgres-source-connector.json \
  http://localhost:8083/connectors
```

Pull the small models used by the agent:

```bash
docker exec -it northstream-ollama ollama pull llama3.2:3b
docker exec -it northstream-ollama ollama pull nomic-embed-text
```

Run the actual demo — same question, with and without live stream context:

```bash
curl -X POST http://localhost:8500/compare \
  -H "Content-Type: application/json" \
  -d '{"question": "Are there any recent sensor anomalies at Plant-B?"}'
```

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

These buckets are intended to represent a simplified data lakehouse layout.

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

## Suggested Repository Layout

```text
northstream/
|
+-- docker-compose-northstream-ai.yml
+-- docker-compose.addon.yml
+-- README.md
+-- init/
|   +-- postgres/
|       +-- 001-init-sales-db.sql
|
+-- trino/
|   +-- catalog/
|       +-- minio.properties
|       +-- postgres.properties
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
+-- docs/
|   +-- architecture.md
|   +-- demo-script.md
|   +-- roadmap.md
|
+-- examples/
    +-- sample-events.json
    +-- sample-queries.sql
```

---

## Demo Narrative

A concise demo narrative:

> NORTHSTREAM shows how operational data can become real-time, governed and AI-ready.  
> It starts with transactional data in PostgreSQL, captures changes through Debezium, streams them through Kafka, applies schema governance, enables stream processing with Flink, stores data in an object-storage-based lakehouse, exposes it through Trino, documents it in OpenMetadata and finally makes it available to a local AI/chat interface — including, via the Stream Context Agent addon, a small local LLM that answers questions grounded in live stream events rather than from static or absent context.

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

Choose the license that best fits your intended usage.

Common options:

- MIT License for permissive sharing
- Apache License 2.0 for permissive sharing with explicit patent terms
- Internal-only license for private enterprise enablement

---

## Disclaimer

NORTHSTREAM is an independent open-source lab concept. It is not affiliated with, endorsed by or certified by IBM, Confluent, Apache Software Foundation, OpenMetadata, Ollama, Open WebUI, Trino, MinIO, Debezium or any other vendor or open-source project mentioned in this repository.

All product names, trademarks and registered trademarks are property of their respective owners.
