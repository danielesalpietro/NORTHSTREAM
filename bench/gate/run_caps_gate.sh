#!/usr/bin/env bash
# Caps gate — confirms at runtime that no service is dying against, or pinned
# to, its own mem_limit. Written after two of v0.0.3's own caps turned out to
# sit below a footprint we had already measured (open-webui 512m, elasticsearch
# 1536m): the release promises honesty about resources, so its caps have to be
# seen running, not only reasoned about.
#
# It DETACHES itself. On ENV-W the interactive CLI session has died four times
# in three days, while the soak's detached sampler survived both deaths it saw.
# So the measurement does not depend on any session staying alive: this script
# returns immediately, the work continues under PPID 1, and the archive is
# closed with checksums by the run itself rather than by whoever comes back.
#
# Usage:  bench/gate/run_caps_gate.sh [minutes] [interval_seconds]
# Default: 40 minutes at 60 s. Prints the archive directory and exits.
#
# It writes raw output verbatim and computes no verdict: the verdict lives in
# verdict_caps.py and is re-runnable against the archive. That separation is
# what let soak #1 be re-adjudicated against thresholds declared after it ran.
set -uo pipefail

MINUTES="${1:-40}"
INTERVAL="${2:-60}"
COMPOSE="${COMPOSE:-docker-compose-northstream-ai.yml}"
PREFIX="${PREFIX:-northstream-}"

if [[ "${NS_GATE_CHILD:-}" != "1" ]]; then
    repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    sha="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo nogit)"
    run_id="$(date -u +%Y%m%d-%H%M)-envw-${sha}-capsgate"
    out="${HOME}/NORTHSTREAM-archive/${run_id}"
    mkdir -p "$out" || { echo "cannot create $out" >&2; exit 1; }
    export NS_GATE_CHILD=1 NS_GATE_OUT="$out" NS_GATE_RUN_ID="$run_id"
    cd "$repo" || exit 1
    setsid nohup "${BASH_SOURCE[0]}" "$MINUTES" "$INTERVAL" \
        >"$out/gate.out.log" 2>"$out/gate.err.log" < /dev/null &
    disown 2>/dev/null || true
    echo "RUN_ID:  $run_id"
    echo "archive: $out"
    echo "detached; ends in ~${MINUTES} min. Verdict afterwards with:"
    echo "  python3 bench/gate/verdict_caps.py \"$out\""
    exit 0
fi

out="$NS_GATE_OUT"

# Environment, recorded and never summarised. Since 2026-08-29 ENV-W has two
# GPUs, so nvidia-smi is stored per device: an aggregate across cards would
# report "free" with one of them busy.
{
    echo "run_id=$NS_GATE_RUN_ID"
    echo "started_utc=$(date -u +%FT%TZ)"
    echo "minutes=$MINUTES interval_s=$INTERVAL compose=$COMPOSE"
    echo "host=$(uname -a)"
} > "$out/manifest.txt"
nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu \
    --format=csv > "$out/gpu.start.csv" 2>"$out/gpu.start.err" \
    || echo "nvidia-smi unavailable -> GPU state unknown, not assumed free" >> "$out/manifest.txt"

docker ps -a --filter "name=${PREFIX}" --format '{{.Names}}' | sort > "$out/containers.txt"
if [[ ! -s "$out/containers.txt" ]]; then
    echo "FATAL: no containers matching ${PREFIX}; bring the stack up first" >> "$out/manifest.txt"
    exit 2
fi

inspect_sweep() {  # $1 = label
    while read -r name; do
        docker inspect "$name" \
            --format '{{.Name}}	{{.RestartCount}}	{{.State.Status}}	{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}	{{.HostConfig.Memory}}	{{.State.OOMKilled}}' \
            2>/dev/null || printf '%s\tunknown\tunknown\tunknown\tunknown\tunknown\n' "$name"
    done < "$out/containers.txt" > "$out/inspect.$1.tsv"
}

inspect_sweep start

end=$(( $(date +%s) + MINUTES * 60 ))
seq=0
while (( $(date +%s) < end )); do
    ts="$(date -u +%FT%TZ)"
    if stats="$(docker stats --no-stream --format '{{.Name}};{{.MemUsage}};{{.MemPerc}}' 2>/dev/null)"; then
        printf '%s\t%s\t%s\n' "$seq" "$ts" "$(printf '%s' "$stats" | tr '\n' '|')" >> "$out/stats.tsv"
    else
        # Never silently skip: a missing sample is recorded as missing, so the
        # verdict can tell "did not happen" from "did not measure".
        printf '%s\t%s\tERROR:docker-stats-failed\n' "$seq" "$ts" >> "$out/stats.tsv"
    fi
    seq=$(( seq + 1 ))
    sleep "$INTERVAL"
done

inspect_sweep end
nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu \
    --format=csv > "$out/gpu.end.csv" 2>/dev/null || true
echo "ended_utc=$(date -u +%FT%TZ) samples=$seq" >> "$out/manifest.txt"

( cd "$out" && sha256sum ./* > SHA256SUMS 2>/dev/null )
echo "DONE $NS_GATE_RUN_ID" >> "$out/manifest.txt"
