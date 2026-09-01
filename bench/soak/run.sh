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
# With --detach it does not merely tolerate outliving its session, it arranges
# to: setsid, PPID 1, prompt back immediately. On ENV-W the operating session
# died four times in three days, and the detached sampler kept the measurement
# every single time -- while the archiving step, which was the session's job,
# was skipped every single time. So the run closes its own archive too: on exit
# it writes SHA256SUMS over its outputs, which is what turns a directory of
# files into a run someone can trust three weeks later. Over 24 hours the
# window in which that matters is 24 hours long.
#
# Usage:
#   bench/soak/run.sh [--interval SECONDS] [--duration SECONDS] \
#                      [--report DIR] [--env TAG] [--repo PATH] \
#                      [--exclusivity exclusive|shared|unknown]
#
# Options:
#   --detach            re-exec under setsid and return immediately (see below)
#   --interval SECONDS  seconds between samples (default: 60)
#   --duration SECONDS  stop after this many seconds (default: 0 = run until
#                        killed — SIGINT/SIGTERM stop cleanly after the
#                        in-flight sample)
#   --report   DIR       where to write the run (default: results/<RUN_ID>)
#   --env      TAG        environment tag for the RUN_ID (default: $NS_ENV or envx)
#   --repo     PATH        repository under test (default: this repository)
#   --exclusivity exclusive|shared|unknown
#                        was ENV-W ours alone for this run (plan section 2.1,
#                        issue #44)? Declared by whoever launches the run, not
#                        inferred — default 'unknown' is honest: nobody said,
#                        not a fabricated "we checked and it's fine".
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
DETACH="no"
ORIGINAL_ARGS=("$@")
REPORT_DIR=""
ENV_TAG="${NS_ENV:-envx}"
REPO="${NS_REPO:-$HARNESS_REPO}"
EXCLUSIVITY="unknown"

while (($#)); do
    case "$1" in
        --interval)    INTERVAL="$2"; shift 2 ;;
        --duration)    DURATION="$2"; shift 2 ;;
        --detach)      DETACH="yes"; shift ;;
        --report)      REPORT_DIR="$2"; shift 2 ;;
        --env)         ENV_TAG="$2"; shift 2 ;;
        --repo)        REPO="$(cd "$2" && pwd)"; shift 2 ;;
        --exclusivity) EXCLUSIVITY="$2"; shift 2 ;;
        -h|--help)  sed -n '2,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$EXCLUSIVITY" in
    exclusive|shared|unknown) ;;
    *) echo "--exclusivity must be exclusive, shared, or unknown (got: $EXCLUSIVITY)" >&2; exit 2 ;;
esac

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 2; }

GIT_SHA="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo nogit)"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%d-%H%M)-${ENV_TAG}-${GIT_SHA}}"
REPORT_DIR="${REPORT_DIR:-$HARNESS_REPO/results/$RUN_ID}"
mkdir -p "$REPORT_DIR"

SAMPLES_FILE="$REPORT_DIR/samples.jsonl"
ERR_LOG="$REPORT_DIR/soak.err.log"
touch "$SAMPLES_FILE" "$ERR_LOG"

# Detach here, once the run identity exists and before any initialisation: the
# child inherits RUN_ID (honoured at the top of this block) so it lands in the
# same directory, and the collection snapshot is taken once, by the process
# that will actually do the sampling.
if [[ "$DETACH" == "yes" && "${NS_SOAK_CHILD:-}" != "1" ]]; then
    export NS_SOAK_CHILD=1 RUN_ID
    setsid nohup "$0" "${ORIGINAL_ARGS[@]}" \
        >"$REPORT_DIR/soak.out.log" 2>>"$ERR_LOG" </dev/null &
    disown 2>/dev/null || true
    echo "RUN_ID:   $RUN_ID"
    echo "report:   $REPORT_DIR"
    echo "detached under PPID 1 — this shell can be closed, the run continues."
    echo "follow:   tail -f $REPORT_DIR/soak.out.log"
    echo "stop:     pkill -f 'soak/run.sh.*$RUN_ID'"
    exit 0
fi

# What the host actually looks like at launch, next to what the launcher said.
#
# The first T-SOAK-24h declared `shared` because a foreign container had been
# seen in a `docker ps` taken before the teardown -- and that container had
# stopped 25 minutes before the run began. The declaration was read from memory
# instead of measured at the moment it was written down, which is the same
# failure the three lessons in CLAUDE.md §5 describe: a declared field standing
# in for a measured one. Diligence had already been applied and still missed it,
# so the check belongs here.
#
# Detection stays advisory. The field is a declaration by contract -- somebody
# has to say whether the machine was theirs -- and a container is only one kind
# of company. So this records what it saw, warns when the two disagree, and
# never silently overwrites what the launcher declared.
NS_PROJECT="${NS_PROJECT:-$(basename "$REPO" | tr '[:upper:]' '[:lower:]')}"
detected_exclusivity="unknown"
foreign_containers=""
if command -v docker >/dev/null 2>&1; then
    all_ids="$(docker ps -q --no-trunc 2>/dev/null)"
    ours="$(docker ps -q --no-trunc --filter "label=com.docker.compose.project=${NS_PROJECT}" 2>/dev/null)"
    if [[ -n "$all_ids" ]]; then
        foreign_ids="$(comm -23 <(printf '%s\n' "$all_ids" | sort) <(printf '%s\n' "$ours" | sort))"
        if [[ -z "${foreign_ids// /}" ]]; then
            detected_exclusivity="exclusive"
        else
            detected_exclusivity="shared"
            foreign_containers="$(docker inspect --format '{{.Name}}' $foreign_ids 2>/dev/null | tr -d '/' | tr '\n' ' ')"
        fi
    fi
fi

if [[ "$detected_exclusivity" != "unknown" && "$EXCLUSIVITY" != "$detected_exclusivity" ]]; then
    echo "WARNING: --exclusivity says '${EXCLUSIVITY}' but the host reads '${detected_exclusivity}' right now." >&2
    [[ -n "$foreign_containers" ]] && echo "         foreign containers: ${foreign_containers}" >&2
    echo "         The declaration is kept as given. Re-check it before the archive is closed." >&2
fi

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date +%s)"

# One-shot pipeline state at run start (connector + replication slot) for the
# manifest's initial conditions (issue #44). Never blocks the run: a failure
# here is captured in the init object itself (null fields, error text), same
# discipline as every other subsystem, not a reason to abort the soak.
INIT_FILE="$REPORT_DIR/.init.json"
if ! python3 "$HARNESS_DIR/lib/sample.py" --mode init >"$INIT_FILE" 2>>"$ERR_LOG"; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) init: sampler exited non-zero collecting initial conditions" >>"$ERR_LOG"
    echo '{"error": "init collection failed, see soak.err.log"}' >"$INIT_FILE"
fi

python3 -c '
import json, sys
init = {}
try:
    with open(sys.argv[9], encoding="utf-8") as fh:
        init = json.load(fh)
except (OSError, json.JSONDecodeError) as exc:
    init = {"error": f"could not read init file: {exc}"}
json.dump({
    "run_id": sys.argv[1], "environment": sys.argv[2], "repo": sys.argv[3],
    "git_sha": sys.argv[4], "interval_seconds": int(sys.argv[5]),
    "duration_seconds": int(sys.argv[6]) or None, "started_at": sys.argv[7],
    "samples_file": "samples.jsonl", "exclusivity": sys.argv[10],
    "exclusivity_detected": sys.argv[11] or None,
    "exclusivity_agrees": (None if sys.argv[11] in ("", "unknown")
                           else sys.argv[11] == sys.argv[10]),
    "foreign_containers_at_launch": [c for c in sys.argv[12].split() if c] or None,
    "initial_conditions": init,
}, open(sys.argv[8], "w"), indent=2)
' "$RUN_ID" "$ENV_TAG" "$REPO" "$GIT_SHA" "$INTERVAL" "$DURATION" "$started_at" \
  "$REPORT_DIR/manifest.json" "$INIT_FILE" "$EXCLUSIVITY" \
  "$detected_exclusivity" "$foreign_containers"
rm -f "$INIT_FILE"

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

# Close the archive here, not in whoever comes back. Soak #1 sat unarchived for
# fifteen hours because the session that was meant to collect it had died; the
# data survived by luck of the volume, not by design.
if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$REPORT_DIR" && sha256sum ./* >SHA256SUMS.tmp 2>/dev/null \
        && mv SHA256SUMS.tmp SHA256SUMS ) \
        && echo "archive closed: $REPORT_DIR/SHA256SUMS ($(wc -l <"$REPORT_DIR/SHA256SUMS") files)" \
        || echo "WARNING: could not write SHA256SUMS — archive is NOT closed" >&2
else
    echo "WARNING: sha256sum unavailable, archive left unchecksummed" >&2
fi

echo
echo "stopped after $seq sample(s) — started $started_at, finished $finished_at"
echo "verdict: python3 $HARNESS_DIR/verdict.py --samples \"$SAMPLES_FILE\" --manifest \"$REPORT_DIR/manifest.json\""
