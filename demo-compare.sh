#!/usr/bin/env bash
# Asks the stream-agent the same question with and without live stream context.
set -euo pipefail

QUESTION="${1:-Are there any recent sensor anomalies at Plant-B?}"

curl -X POST http://localhost:8500/compare \
  -H "Content-Type: application/json" \
  -d "{\"question\": \"${QUESTION}\"}"
