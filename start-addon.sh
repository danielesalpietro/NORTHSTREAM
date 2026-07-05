#!/usr/bin/env bash
# Starts NORTHSTREAM base stack + Stream Context Agent addon.
set -euo pipefail

docker compose \
  -f docker-compose-northstream-ai.yml \
  -f docker-compose.addon.yml \
  up -d --build
