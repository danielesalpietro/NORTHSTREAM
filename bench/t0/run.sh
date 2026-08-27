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

# Hard ceiling per test, so one wedged test cannot consume the whole CI budget.
NS_TEST_TIMEOUT="${NS_TEST_TIMEOUT:-600}"

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

# A test whose own parameters exceed the global ceiling would be killed before it
# could measure anything: T0.9 has to let an event grow stale, so its floor is the
# recency threshold plus the fixed cost of indexing, asking and cleaning up.
test_timeout_for() {
    local id="$1"
    if [[ "$id" == "T0.9" ]]; then
        local floor=$(( ${NS_RECENCY_SECONDS:-300} + 300 ))
        if (( floor > NS_TEST_TIMEOUT )); then
            printf '%s' "$floor"
            return
        fi
    fi
    printf '%s' "$NS_TEST_TIMEOUT"
}

# What actually ran, for the manifest: image ids and digests of the northstream
# containers plus the models loaded in Ollama. Required by section 3 of
# docs/piano_ricovero.md — a run nobody can reproduce is not a measurement.
collect_environment() {
    local images="" models="" name image id digest
    if command -v docker >/dev/null 2>&1; then
        while IFS=$'\t' read -r name image; do
            [[ -z "$name" ]] && continue
            id="$(docker inspect --format '{{.Id}}' "$image" 2>/dev/null || true)"
            digest="$(docker inspect --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' "$image" 2>/dev/null || true)"
            images+="${name}"$'\t'"${image}"$'\t'"${id}"$'\t'"${digest}"$'\n'
        done < <(docker ps --filter 'name=northstream-' --format '{{.Names}}\t{{.Image}}' 2>/dev/null)
        # Exit status, not output: a failed exec (the CI mock has no ollama
        # binary) must record "no models observed", never its own error text
        # dressed up as a model.
        if ! models="$(docker exec northstream-ollama ollama list 2>/dev/null)"; then
            models=""
        fi
    fi
    NS_ENV_IMAGES="$images" NS_ENV_MODELS="$models" python3 -c '
import json, os, sys
images = []
for line in os.environ.get("NS_ENV_IMAGES", "").splitlines():
    if not line.strip():
        continue
    parts = (line.split("\t") + ["", "", "", ""])[:4]
    images.append({"container": parts[0], "image": parts[1],
                   "image_id": parts[2], "digest": parts[3]})
models = [l for l in os.environ.get("NS_ENV_MODELS", "").splitlines()
          if l.strip() and not l.startswith("NAME")]
json.dump({"images": images, "models": models}, open(sys.argv[1], "w"), indent=2)
' "$1"
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
    # No single test may hang the suite: a wedged probe becomes a KO with a
    # recorded duration, not a job that runs until the CI timeout kills it.
    test_timeout="$(test_timeout_for "$id")"
    NS_REPO="$REPO" NS_RESULTS="$REPORT_DIR" \
        timeout --signal=TERM --kill-after=30 "$test_timeout" \
        bash "$script" >>"$REPORT_DIR/${id}.log" 2>&1
    code=$?
    duration=$(( $(date +%s) - start ))

    if (( code == 124 || code == 137 )); then
        echo "    (killed after ${test_timeout}s)" >>"$REPORT_DIR/${id}.log"
        code=1
    fi

    case "$code" in
        0) observed="OK" ;;
        2) observed="SKIP" ;;
        *) observed="KO" ;;
    esac

    summary="test interrupted before it could report (see ${id}.log)"
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

# What the stack was made of, so the run can be reproduced or its differences
# explained later (docs/piano_ricovero.md section 3).
env_file="$(mktemp)"
collect_environment "$env_file"

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
    'stack': json.load(open(sys.argv[2])) if len(sys.argv) > 2 else {},
    'counts': counts,
    'results': results,
}, open(sys.argv[1], 'w'), indent=2)
print(json.dumps(counts))
" "$REPORT_DIR/manifest.json" "$env_file" >"$REPORT_DIR/.counts"

counts="$(cat "$REPORT_DIR/.counts")"
rm -f "$REPORT_DIR/.counts" "$env_file"

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

# SHA256SUMS last, over everything else: an archive nobody can verify is not an
# archive (docs/piano_ricovero.md section 3, and the RunPod shutdown rule).
if command -v sha256sum >/dev/null 2>&1; then
    (
        cd "$REPORT_DIR" || exit 0
        find . -type f ! -name SHA256SUMS -print0 | sort -z |
            xargs -0 sha256sum >SHA256SUMS
        if sha256sum -c --status SHA256SUMS; then
            echo "checksums: $(wc -l <SHA256SUMS) file(s), verified"
        else
            echo "checksums: SHA256SUMS did not verify against its own directory" >&2
        fi
    )
else
    echo "checksums: sha256sum not available, SHA256SUMS not generated" >&2
fi

echo "counts:  $counts"
echo "report:  $REPORT_DIR/summary.md"

if ((blocking > 0)); then
    echo "RESULT:  FAILED ($blocking blocking)"
    exit 1
fi
echo "RESULT:  OK (no regression)"
exit 0
