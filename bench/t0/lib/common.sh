# shellcheck shell=bash
# Shared helpers for the T0 test scripts.
#
# Every test script is standalone: it can be executed directly (for debugging)
# or through bench/t0/run.sh. It must not depend on any other test having run
# before it — each test prepares and cleans its own sentinel data.
#
# Exit code contract (read by run.sh):
#   0 -> the asserted behaviour holds        (observed OK)
#   1 -> the asserted behaviour does not hold (observed KO)
#   2 -> the test could not run at all       (missing prerequisite -> SKIP)
#
# run.sh compares the observed outcome with the expectation declared in
# bench/t0/expected/*.json and derives PASS / XFAIL / FAIL / XPASS from it.

set -uo pipefail

NS_OK=0
NS_KO=1
NS_SKIP=2

# Repository under test: the checkout whose compose files and code we exercise.
# Defaults to the repository this harness lives in, but can point at a separate
# checkout (e.g. the v0.0.0-baseline tag) so the harness never has to modify it.
NS_REPO="${NS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
NS_RESULTS="${NS_RESULTS:-}"

# Fixed sentinel values. They are constants of the repository on purpose: an
# input nobody can tune per-run is an input anybody can verify.
NS_SENTINEL_TEMP="77.31"          # T0.3 / T0.4 — CDC and buffer visibility
NS_SENTINEL_VIB="0.411"
NS_SENTINEL_SITE="Plant-A"
NS_ANOMALY_TEMP="91.73"           # T0.5 — grounded answer
NS_ANOMALY_VIB="1.234"
NS_ANOMALY_SITE="Plant-B"
NS_UNKNOWN_SITE="Depot-9"         # T0.10 — site outside KNOWN_SITES
NS_UNKNOWN_TEMP="93.17"

# Container names are fixed by the compose files, so they hold whatever the
# compose project is called.
NS_C_POSTGRES="${NS_C_POSTGRES:-northstream-source-postgres}"
NS_C_KAFKA="${NS_C_KAFKA:-northstream-kafka}"
NS_C_CONNECT="${NS_C_CONNECT:-northstream-debezium-connect}"
NS_C_QDRANT="${NS_C_QDRANT:-northstream-qdrant}"
NS_C_OLLAMA="${NS_C_OLLAMA:-northstream-ollama}"
NS_C_AGENT="${NS_C_AGENT:-northstream-stream-agent}"
NS_C_GENERATOR="${NS_C_GENERATOR:-northstream-data-generator}"
NS_C_TRINO="${NS_C_TRINO:-northstream-trino}"

# Host endpoints used by tests that legitimately talk from the host.
NS_AGENT_URL="${NS_AGENT_URL:-http://localhost:8500}"
NS_QDRANT_URL="${NS_QDRANT_URL:-http://localhost:6333}"
NS_CONNECT_URL="${NS_CONNECT_URL:-http://localhost:8083}"
# Port 29092 is the EXTERNAL listener added by the dual-listener setup
# (finding P-1, issue #16): 9092 is now INTERNAL-only, advertised as
# kafka:9092 and unusable from the host on purpose.
NS_KAFKA_HOST_BOOTSTRAP="${NS_KAFKA_HOST_BOOTSTRAP:-localhost:29092}"

# Timeouts (seconds). Overridable so the same test can run fast in CI and
# realistically on a workstation.
NS_STACK_TIMEOUT="${NS_STACK_TIMEOUT:-420}"
NS_INDEX_TIMEOUT="${NS_INDEX_TIMEOUT:-240}"
NS_CDC_TIMEOUT="${NS_CDC_TIMEOUT:-30}"
NS_AGENT_TIMEOUT="${NS_AGENT_TIMEOUT:-60}"
# Default 300, not 900: the per-test ceiling is 600s, so a 900s threshold would
# always be killed before T0.9 could measure anything. A run that wants the
# stronger assertion passes a bigger value and run.sh scales that test's timeout.
NS_RECENCY_SECONDS="${NS_RECENCY_SECONDS:-300}"

_ns_test_id=""
_ns_detail_file=""

ns_log() {
    printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2
}

ns_init() {
    _ns_test_id="$1"
    _ns_detail_file="$(mktemp)"
}

# Record a human-readable observation. Everything recorded here ends up in the
# test's JSON, which is what makes a run auditable after the fact.
ns_observe() {
    printf '%s\n' "$*" >>"$_ns_detail_file"
    ns_log "  $*"
}

_ns_json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# ns_finish <exit_code> <summary>
# Writes the per-test JSON (when NS_RESULTS is set) and exits with the code.
ns_finish() {
    local code="$1"
    local summary="${2:-}"
    local observations="[]"

    if [[ -s "$_ns_detail_file" ]]; then
        observations="$(python3 -c '
import json, sys
print(json.dumps([line.rstrip("\n") for line in sys.stdin if line.strip()]))
' <"$_ns_detail_file")"
    fi

    if [[ -n "$NS_RESULTS" ]]; then
        mkdir -p "$NS_RESULTS"
        {
            printf '{\n'
            printf '  "test": "%s",\n' "$_ns_test_id"
            printf '  "observed": "%s",\n' "$(ns_outcome_name "$code")"
            printf '  "exit_code": %s,\n' "$code"
            printf '  "summary": %s,\n' "$(printf '%s' "$summary" | _ns_json_escape)"
            printf '  "observations": %s\n' "$observations"
            printf '}\n'
        } >"$NS_RESULTS/${_ns_test_id}.json"
    fi

    rm -f "$_ns_detail_file"
    ns_log "$_ns_test_id -> $(ns_outcome_name "$code"): $summary"
    exit "$code"
}

ns_outcome_name() {
    case "$1" in
        0) printf 'OK' ;;
        2) printf 'SKIP' ;;
        *) printf 'KO' ;;
    esac
}

ns_have_docker() {
    command -v docker >/dev/null 2>&1
}

ns_container_running() {
    [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]
}

# Requires the named containers to be running; SKIPs the test otherwise, since
# "the stack is not up" is not the same as "the behaviour is broken".
ns_require_containers() {
    if ! ns_have_docker; then
        ns_finish "$NS_SKIP" "docker CLI not available"
    fi
    local missing=()
    local c
    for c in "$@"; do
        ns_container_running "$c" || missing+=("$c")
    done
    if ((${#missing[@]})); then
        ns_finish "$NS_SKIP" "containers not running: ${missing[*]}"
    fi
}

ns_psql() {
    docker exec "$NS_C_POSTGRES" psql -U demo -d sales -tAq -c "$1"
}

# Deletes the sentinel rows this suite injects, so a test never inherits the
# leftovers of a previous run.
ns_cleanup_sentinels() {
    ns_psql "DELETE FROM sensor_readings WHERE temperature_c IN (${NS_SENTINEL_TEMP}, ${NS_ANOMALY_TEMP}, ${NS_UNKNOWN_TEMP});" >/dev/null 2>&1 || true
}

ns_insert_sensor_row() {
    local site="$1" temp="$2" vib="$3" anomaly="$4"
    ns_psql "INSERT INTO sensor_readings (site, temperature_c, vibration_g, is_anomaly) VALUES ('${site}', ${temp}, ${vib}, ${anomaly});"
}

ns_curl_json() {
    curl -sS --max-time 30 "$@"
}

ns_post_json() {
    local url="$1" body="$2"
    curl -sS --max-time 180 -X POST "$url" -H 'Content-Type: application/json' -d "$body"
}

# Reads a value out of a JSON document on stdin with a tiny python expression,
# e.g. ns_json_get '.["context_used"]' — kept deliberately dependency-free
# (no jq) so the harness runs on a bare runner.
ns_json_get() {
    python3 -c "
import json, sys
doc = json.load(sys.stdin)
sys.stdout.write(str(eval('doc' + sys.argv[1])))
" "$1" 2>/dev/null
}

ns_json_contains() {
    local needle="$1"
    python3 -c "
import json, sys
needle = sys.argv[1]
print('yes' if needle in json.dumps(json.load(sys.stdin)) else 'no')
" "$needle" 2>/dev/null
}

ns_now() {
    date +%s
}
