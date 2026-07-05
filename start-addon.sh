#!/usr/bin/env bash
# Starts NORTHSTREAM base stack + Stream Context Agent addon.
# Usage: ./start-addon.sh          (CPU only)
#        ./start-addon.sh --gpu    (adds NVIDIA GPU passthrough for Ollama)
set -euo pipefail

COMPOSE_ARGS=(-f docker-compose-northstream-ai.yml -f docker-compose.addon.yml)

if [[ "${1:-}" == "--gpu" ]]; then
  COMPOSE_ARGS+=(-f docker-compose.gpu.yml)
fi

docker compose "${COMPOSE_ARGS[@]}" up -d --build
