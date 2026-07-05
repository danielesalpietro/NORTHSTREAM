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

```powershell
.\start-addon.ps1
```

```bash
./start-addon.sh
```

(add `-Gpu` / `--gpu` for GPU passthrough; equivalent to
`docker compose -f docker-compose-northstream-ai.yml -f docker-compose.addon.yml up -d --build`)

Wait until Kafka, Postgres, Debezium Connect, Ollama and Qdrant are
`healthy` (`docker compose ps`).

## 2. Register the Debezium CDC connector

```powershell
.\register-connector.ps1
```

```bash
./register-connector.sh
```

This also prints the connector status. The connector config
([`connectors/postgres-source-connector.json`](../connectors/postgres-source-connector.json))
sets `decimal.handling.mode: double` so `NUMERIC` columns
(`temperature_c`, `vibration_g`, `unit_price`, `total_amount`) stream as
plain numbers instead of base64-encoded bytes.

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

## 5. The actual demo: /compare (command line)

Ask the same question to the model with and without stream context:

```powershell
.\demo-compare.ps1
```

```bash
./demo-compare.sh
```

or directly:

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

## 5b. The same demo, from Open WebUI

`stream-agent` also exposes an OpenAI-compatible API (`/v1/models`,
`/v1/chat/completions`), so the same before/after comparison can be run as an
actual chat instead of curl calls — better for live presentations.

1. Open [http://localhost:3000](http://localhost:3000) (create the local
   admin account on first launch).
2. **Admin Panel → Settings → Connections → OpenAI API** → add a connection
   with Base URL `http://stream-agent:8500/v1` and any non-empty API key.
   A `northstream-grounded` model appears in the model picker.
3. **Workspace → Models → granite4:1b → edit**: uncheck everything under
   **Builtin Tools**. Without this, the model may try to answer by invoking
   an unrelated built-in tool (e.g. searching its calendar for "Plant-B")
   instead of answering from its own knowledge, which defeats the baseline
   comparison.
4. Ask the demo question in a **new chat** with `granite4:1b` (baseline), then
   in another **new chat** with `northstream-grounded` (grounded). Always use
   a fresh chat per side — reusing a thread lets the model repeat its own
   earlier answer from history instead of reasoning again.

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
