# Demo: "a small, well-fed LLM beats a large one running dry"

This addon plugs into the existing NORTHSTREAM stack and adds the missing
layer flagged in the README ("Streaming Data Agent" / chat with data).

## 0. Prerequisites

You need to already have the `docker-compose-northstream-ai.yml` file from
the NORTHSTREAM project in the same folder where you copy this addon's
content (or adjust the paths with `-f`).

Expected final layout:

```text
northstream/
├── docker-compose-northstream-ai.yml   (existing)
├── docker-compose.addon.yml            (new)
├── init/postgres/001-init-sales-db.sql (new)
├── connectors/postgres-source-connector.json (new)
├── stream-agent/...                    (new)
└── data-generator/...                  (new)
```

## 1. Start everything

```bash
docker compose \
  -f docker-compose-northstream-ai.yml \
  -f docker-compose.addon.yml \
  up -d --build
```

Wait until Kafka, Postgres, Debezium Connect, Ollama and Qdrant are
`healthy` (`docker compose ps`).

## 2. Register the Debezium CDC connector

```bash
curl -X POST -H "Content-Type: application/json" \
  --data @connectors/postgres-source-connector.json \
  http://localhost:8083/connectors
```

Check its status:

```bash
curl http://localhost:8083/connectors/northstream-postgres-connector/status
```

## 3. Pull the Ollama models (small, on purpose)

IBM Granite, open-source and aligned with the watsonx narrative:

```bash
docker exec -it northstream-ollama ollama pull granite4:1b
docker exec -it northstream-ollama ollama pull granite-embedding:30m
```

## 4. Let the data generator run for a couple of minutes

The `northstream-data-generator` container continuously inserts orders and
sensor readings (with occasional anomalies) into Postgres. Debezium captures
them, Kafka distributes them, `stream-agent` consumes them and indexes them
in Qdrant.

Check that the buffer is filling up:

```bash
curl http://localhost:8500/health
curl http://localhost:8500/events?limit=10
```

## 5. The actual demo: /compare

Ask the same question to the model with and without stream context:

```bash
curl -X POST http://localhost:8500/compare \
  -H "Content-Type: application/json" \
  -d '{"question": "Are there any recent sensor anomalies at Plant-B? What temperature and vibration values were recorded?"}'
```

Typical response:

- `without_stream_context` → the model answers generically or makes things
  up, because it has no real information about "Plant-B" today.
- `with_stream_context` → the model cites the actual values that just arrived
  from the stream (temperature, vibration, whether it's an anomaly), because
  you passed them in as context retrieved from Qdrant.

More example questions useful for the demo:

```text
"What is the total value of Acme Corp's most recent orders?"
"Which products are selling best in the EMEA region right now?"
"Are there any temperature readings above 85 degrees in the last few minutes?"
```

## 6. The takeaway (for presales/workshop)

The quality of a small LLM's answer (1B parameters) does not depend on its
size, but on the quality and freshness of the data it is fed at the moment
of the question. This is the same principle behind watsonx.data: the value
proposition is not "a bigger model", it's "an integrated, governed, real-time
data foundation" that makes any model useful, even a small local one.

## 7. Tear everything down

```bash
docker compose \
  -f docker-compose-northstream-ai.yml \
  -f docker-compose.addon.yml \
  down -v
```
