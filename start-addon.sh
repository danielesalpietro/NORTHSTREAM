#!/usr/bin/env bash
# Starts NORTHSTREAM base stack + Stream Context Agent addon.
# Usage: ./start-addon.sh                        (everything, CPU only — today's default)
#        ./start-addon.sh --gpu                  (everything, GPU passthrough for Ollama)
#        ./start-addon.sh --profile core         (lean pipeline only: P-5, issue #21)
#        ./start-addon.sh --profile core,lakehouse --gpu
#
# Compose profiles (core/lakehouse/governance) were introduced in v0.0.3.
# Default stays "start everything" — the behaviour every caller (this
# script, ci-nightly) already depended on — by passing all three profiles
# unless --profile narrows it. core services have no profile tag of their
# own, so they start regardless of which profiles are requested.
set -euo pipefail

COMPOSE_ARGS=(-f docker-compose-northstream-ai.yml -f docker-compose.addon.yml)
PROFILES="core,lakehouse,governance"

while (($#)); do
  case "$1" in
    --gpu)     COMPOSE_ARGS+=(-f docker-compose.gpu.yml); shift ;;
    --profile) PROFILES="$2"; shift 2 ;;
    *)         echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

IFS=',' read -ra PROFILE_LIST <<< "$PROFILES"
for p in "${PROFILE_LIST[@]}"; do
  COMPOSE_ARGS+=(--profile "$p")
done

docker compose "${COMPOSE_ARGS[@]}" up -d --build
