#!/usr/bin/env bash
# Registers the Debezium Postgres CDC connector with Kafka Connect.
set -euo pipefail

curl -X POST -H "Content-Type: application/json" \
  --data @connectors/postgres-source-connector.json \
  http://localhost:8083/connectors

echo ""
echo "Connector status:"
curl -s http://localhost:8083/connectors/northstream-postgres-connector/status
