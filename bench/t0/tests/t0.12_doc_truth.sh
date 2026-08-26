#!/usr/bin/env bash
# T0.12 — the README describes the repository that actually exists.
# Input:  a clean checkout; no running stack required.
# Expect: zero violations from bench/t0/lib/doc_truth.py.
# Baseline expectation: XFAIL (D-1, D-2, P-1 doc). Flips in v0.0.1.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.12"

linter="$(dirname "${BASH_SOURCE[0]}")/../lib/doc_truth.py"

if ! python3 -c "import yaml" >/dev/null 2>&1; then
    ns_finish "$NS_SKIP" "PyYAML not available: cannot parse the compose files"
fi

json_arg=()
[[ -n "$NS_RESULTS" ]] && { mkdir -p "$NS_RESULTS"; json_arg=(--json "$NS_RESULTS/T0.12-violations.json"); }

output="$(python3 "$linter" --repo "$NS_REPO" "${json_arg[@]}" 2>&1)"
status=$?

while IFS= read -r line; do
    [[ -n "$line" ]] && ns_observe "$line"
done <<<"$output"

if (( status == 0 )); then
    ns_finish "$NS_OK" "no documentation violations"
fi

count="$(printf '%s\n' "$output" | grep -c '^T0\.12-' || true)"
ns_finish "$NS_KO" "${count} documentation violation(s) (D-1, D-2, P-1 doc)"
