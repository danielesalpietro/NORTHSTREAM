# Starts NORTHSTREAM base stack + Stream Context Agent addon.
$ErrorActionPreference = "Stop"

docker compose `
  -f docker-compose-northstream-ai.yml `
  -f docker-compose.addon.yml `
  up -d --build
