#!/usr/bin/env bash
# NORTHSTREAM soak sampler — orchestrator for T-SOAK-24h (docs/piano_ricovero.md
# section 4.3), built ahead of its v0.0.4 scope per CLAUDE.md section 3.2 (test
# infrastructure may be anticipated; it measures, it does not modify the system).
#
# Samples the running stack at a fixed interval, append-only, one JSON line per
# sample (bench/soak/lib/sample.py). Never modifies the stack, never aborts on
# a degraded subsystem, and is safe to run under nohup/tmux for 24h+: a kill at
# any point leaves every prior sample readable.
#
# Usage:
#   bench/soak/run.sh [--interval SECONDS] [--duration SECONDS] \
#                      [--report DIR] [--env TAG] [--repo PATH]
#
# Options:
#   --interval SECONDS  seconds between samples (default: 60)
#   --duration SECONDS  stop after this many seconds (default: 0 = run until
#                        killed — SIGINT/SIGTERM stop cleanly after the
#                        in-flight sample)
#   --report   DIR       where to write the run (default: results/<RUN_ID>)
#   --env      TAG        environment tag for the RUN_ID (default: $NS_ENV or envx)
#   --repo     PATH        repository under test (default: this repository)
#
# Recommended: run under tmux/nohup, not inside an interactive session that can
# drop —  CLAUDE.md section 5 documents the exact lesson (a dropped SSH
# connection killed a deploy mid-way).
#
#   tmux new -s northstream-soak
#   bench/soak/run.sh --interval 60 --duration $((24*3600)) --env envw
#
# Output (results/<RUN_ID>/):
#   manifest.json   static run info, written once at start
#   samples.jsonl   one line per sample, append-only
#   soak.err.log    subsystem errors from individual samples (non-fatal)
#
# Run bench/soak/verdict.py against samples.jsonl afterwards (or at any point
# mid-run) to turn the samples into a PASS/WARN read on the four checks.
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_REPO="$(cd "$HARNESS_DIR/../.." && pwd)"

INTERVAL=60
DURATION=0
REPORT_DIR=""
ENV_TAG="${NS_ENV:-envx}"
REPO="${NS_REPO:-$HARNESS_REPO}"

while (($#)); do
    case "$1" in
        --interval) INTERVAL="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --report)   REPORT_DIR="$2"; shift 2 ;;
        --env)      ENV_TAG="$2"; shift 2 ;;
        --repo)     REPO="$(cd "$2" && pwd)"; shift 2 ;;
        -h|--help)  sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 2; }

GIT_SHA="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo nogit)"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%d-%H%M)-${ENV_TAG}-${GIT_SHA}}"
REPORT_DIR="${REPORT_DIR:-$HARNESS_REPO/results/$RUN_ID}"
mkdir -p "$REPORT_DIR"

SAMPLES_FILE="$REPORT_DIR/samples.jsonl"
ERR_LOG="$REPORT_DIR/soak.err.log"
touch "$SAMPLES_FILE" "$ERR_LOG"

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date +%s)"

python3 -c '
import json, sys
json.dump({
    "run_id": sys.argv[1], "environment": sys.argv[2], "repo": sys.argv[3],
    "git_sha": sys.argv[4], "interval_seconds": int(sys.argv[5]),
    "duration_seconds": int(sys.argv[6]) or None, "started_at": sys.argv[7],
    "samples_file": "samples.jsonl", "exclusivity": "unknown",
}, open(sys.argv[8], "w"), indent=2)
' "$RUN_ID" "$ENV_TAG" "$REPO" "$GIT_SHA" "$INTERVAL" "$DURATION" "$started_at" "$REPORT_DIR/manifest.json"

echo "RUN_ID:   $RUN_ID"
echo "interval: ${INTERVAL}s · duration: $([[ "$DURATION" -gt 0 ]] && echo "${DURATION}s" || echo "until stopped")"
echo "report:   $REPORT_DIR"
echo "samples:  $SAMPLES_FILE"
echo

stop=0
trap 'stop=1' INT TERM

seq=0
while [[ "$stop" -eq 0 ]]; do
    if [[ "$DURATION" -gt 0 ]]; then
        now_epoch="$(date +%s)"
        (( now_epoch - started_epoch >= DURATION )) && break
    fi

    if ! python3 "$HARNESS_DIR/lib/sample.py" --seq "$seq" --out "$SAMPLES_FILE" 2>>"$ERR_LOG"; then
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) sample $seq: sampler exited non-zero, continuing" >>"$ERR_LOG"
    fi
    seq=$((seq + 1))

    [[ "$stop" -eq 1 ]] && break
    sleep "$INTERVAL" &
    wait $! 2>/dev/null
done

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
echo "stopped after $seq sample(s) — started $started_at, finished $finished_at"
echo "verdict: python3 $HARNESS_DIR/verdict.py --samples \"$SAMPLES_FILE\" --manifest \"$REPORT_DIR/manifest.json\""
