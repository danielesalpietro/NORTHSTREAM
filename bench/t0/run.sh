#!/usr/bin/env bash
# NORTHSTREAM T0 harness.
#
# Runs the T0 suite defined in docs/piano_ricovero.md section 4.1 and compares
# every observed outcome with the expectation declared for the target under
# test, producing PASS / XFAIL / FAIL / XPASS / SKIP.
#
#   PASS   expected to work, and it works        -> must never regress
#   XFAIL  known defect, still failing            -> the release that fixes it says so
#   FAIL   expected to work, but it does not      -> blocking
#   XPASS  known defect, unexpectedly passing     -> good news, but explain it
#   SKIP   prerequisite missing                   -> no claim either way
#
# Usage:
#   bench/t0/run.sh --suite ci|core|full|static [options]
#
# Options:
#   --suite <name>      which subset to run (default: core)
#   --only  <ids>       comma-separated test ids, e.g. --only T0.3,T0.12
#   --repo  <path>      repository under test (default: this repository)
#   --expected <file>   expectations file (default: expected/current.json)
#   --report <dir>      where to write the report (default: results/<RUN_ID>)
#   --env <id>          environment tag for the RUN_ID (default: $NS_ENV or envx)
#   --list              print the suite composition and exit
#
# Exit code: 0 when no test FAILs, 1 otherwise. XPASS and SKIP are reported but
# do not fail the run: only a broken PASS blocks.
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_REPO="$(cd "$HARNESS_DIR/../.." && pwd)"

SUITE="core"
ONLY=""
REPO="${NS_REPO:-$HARNESS_REPO}"
EXPECTED_FILE="$HARNESS_DIR/expected/current.json"
REPORT_DIR=""
ENV_TAG="${NS_ENV:-envx}"
LIST_ONLY="no"

# Suite composition. 'ci' matches the ci-smoke workflow (no GPU, mock Ollama);
# 'static' needs neither a running stack nor a Docker daemon for T0.12.
SUITE_CI="T0.1 T0.2 T0.3 T0.4 T0.8 T0.11"
SUITE_STATIC="T0.1 T0.12"
SUITE_CORE="T0.1 T0.2 T0.3 T0.4 T0.5 T0.6 T0.7 T0.8 T0.11 T0.12"
SUITE_FULL="T0.1 T0.2 T0.3 T0.4 T0.5 T0.6 T0.7 T0.8 T0.9 T0.10 T0.11 T0.12"

while (($#)); do
    case "$1" in
        --suite)    SUITE="$2"; shift 2 ;;
        --only)     ONLY="$2"; shift 2 ;;
        --repo)     REPO="$(cd "$2" && pwd)"; shift 2 ;;
        --expected) EXPECTED_FILE="$2"; shift 2 ;;
        --report)   REPORT_DIR="$2"; shift 2 ;;
        --env)      ENV_TAG="$2"; shift 2 ;;
        --list)     LIST_ONLY="yes"; shift ;;
        -h|--help)  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$SUITE" in
    ci)     TESTS="$SUITE_CI" ;;
    static) TESTS="$SUITE_STATIC" ;;
    core)   TESTS="$SUITE_CORE" ;;
    full)   TESTS="$SUITE_FULL" ;;
    *)      echo "unknown suite: $SUITE (use ci, static, core or full)" >&2; exit 2 ;;
esac

if [[ -n "$ONLY" ]]; then
    TESTS="$(echo "$ONLY" | tr ',' ' ')"
fi

test_script() {
    local id="${1#T0.}"
    printf -v id '%02d' "$id" 2>/dev/null || return 1
    local match
    match="$(find "$HARNESS_DIR/tests" -name "t0.${id}_*.sh" | head -1)"
    [[ -n "$match" ]] && printf '%s' "$match"
}

if [[ "$LIST_ONLY" == "yes" ]]; then
    echo "suite '$SUITE':"
    for id in $TESTS; do
        printf '  %-6s %s\n' "$id" "$(basename "$(test_script "$id")")"
    done
    exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 2; }
[[ -f "$EXPECTED_FILE" ]] || { echo "expectations file not found: $EXPECTED_FILE" >&2; exit 2; }

GIT_SHA="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo nogit)"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%d-%H%M)-${ENV_TAG}-${GIT_SHA}}"
REPORT_DIR="${REPORT_DIR:-$HARNESS_REPO/results/$RUN_ID}"
mkdir -p "$REPORT_DIR"

expected_for() {
    python3 -c "
import json, sys
doc = json.load(open(sys.argv[1]))
print(doc.get('expected', {}).get(sys.argv[2], 'PASS'))
" "$EXPECTED_FILE" "$1"
}

flip_note_for() {
    python3 -c "
import json, sys
doc = json.load(open(sys.argv[1]))
print(doc.get('flips', {}).get(sys.argv[2], ''))
" "$EXPECTED_FILE" "$1"
}

verdict_for() {
    local expected="$1" observed="$2"
    case "${expected}/${observed}" in
        PASS/OK)    printf 'PASS' ;;
        PASS/KO)    printf 'FAIL' ;;
        XFAIL/KO)   printf 'XFAIL' ;;
        XFAIL/OK)   printf 'XPASS' ;;
        */SKIP)     printf 'SKIP' ;;
        *)          printf 'UNKNOWN' ;;
    esac
}

echo "RUN_ID:   $RUN_ID"
echo "suite:    $SUITE ($TESTS)"
echo "repo:     $REPO"
echo "expected: $EXPECTED_FILE"
echo "report:   $REPORT_DIR"
echo

declare -a ROWS=()
blocking=0
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

for id in $TESTS; do
    script="$(test_script "$id")"
    if [[ -z "$script" ]]; then
        echo "!! no script found for $id" >&2
        ROWS+=("$id|UNKNOWN|-|0|no script found for $id")
        blocking=$((blocking + 1))
        continue
    fi

    expected="$(expected_for "$id")"
    echo "--- $id ($(basename "$script")) — expected: $expected"

    start="$(date +%s)"
    NS_REPO="$REPO" NS_RESULTS="$REPORT_DIR" bash "$script" >>"$REPORT_DIR/${id}.log" 2>&1
    code=$?
    duration=$(( $(date +%s) - start ))

    case "$code" in
        0) observed="OK" ;;
        2) observed="SKIP" ;;
        *) observed="KO" ;;
    esac

    summary=""
    if [[ -f "$REPORT_DIR/${id}.json" ]]; then
        summary="$(python3 -c "
import json, sys
print(json.load(open(sys.argv[1])).get('summary', ''))
" "$REPORT_DIR/${id}.json")"
    fi

    verdict="$(verdict_for "$expected" "$observed")"
    [[ "$verdict" == "FAIL" || "$verdict" == "UNKNOWN" ]] && blocking=$((blocking + 1))

    printf '    %-6s %-6s (%ss) %s\n\n' "$verdict" "$observed" "$duration" "$summary"
    ROWS+=("$id|$verdict|$expected|$duration|$summary")
done

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# manifest.json — the machine-readable record of this run.
{
    printf '%s\n' "$RUN_ID" "$SUITE" "$REPO" "$GIT_SHA" "$ENV_TAG" "$EXPECTED_FILE" "$started_at" "$finished_at"
    printf '%s\n' "${ROWS[@]}"
} | python3 -c "
import json, sys
lines = [line.rstrip('\n') for line in sys.stdin]
run_id, suite, repo, sha, env, expected_file, started, finished = lines[:8]
results = []
for row in lines[8:]:
    if not row:
        continue
    test, verdict, expected, duration, summary = row.split('|', 4)
    results.append({
        'test': test,
        'verdict': verdict,
        'expected': expected,
        'duration_seconds': int(duration),
        'summary': summary,
    })
counts = {}
for entry in results:
    counts[entry['verdict']] = counts.get(entry['verdict'], 0) + 1
json.dump({
    'run_id': run_id,
    'suite': suite,
    'repo': repo,
    'git_sha': sha,
    'environment': env,
    'expected_file': expected_file,
    'started_at': started,
    'finished_at': finished,
    'counts': counts,
    'results': results,
}, open(sys.argv[1], 'w'), indent=2)
print(json.dumps(counts))
" "$REPORT_DIR/manifest.json" >"$REPORT_DIR/.counts"

counts="$(cat "$REPORT_DIR/.counts")"
rm -f "$REPORT_DIR/.counts"

# summary.md — the human-readable table that goes into docs/runs/.
{
    echo "# T0 run \`$RUN_ID\`"
    echo
    echo "- **Suite**: \`$SUITE\` · **Ambiente**: \`$ENV_TAG\` · **Repo sotto test**: \`$REPO\` @ \`$GIT_SHA\`"
    echo "- **Attese**: \`$(basename "$EXPECTED_FILE")\` · **Inizio**: $started_at · **Fine**: $finished_at"
    echo
    echo "| Test | Esito | Atteso | Durata | Note |"
    echo "|---|---|---|---|---|"
    for row in "${ROWS[@]}"; do
        IFS='|' read -r id verdict expected duration summary <<<"$row"
        note="$summary"
        flip="$(flip_note_for "$id")"
        [[ "$verdict" == "XFAIL" && -n "$flip" ]] && note="$note — flip atteso in $flip"
        printf '| %s | **%s** | %s | %ss | %s |\n' "$id" "$verdict" "$expected" "$duration" "$note"
    done
    echo
    echo "Conteggi: \`$counts\`"
} >"$REPORT_DIR/summary.md"

echo "counts:  $counts"
echo "report:  $REPORT_DIR/summary.md"

if ((blocking > 0)); then
    echo "RESULT:  FAILED ($blocking blocking)"
    exit 1
fi
echo "RESULT:  OK (no regression)"
exit 0
