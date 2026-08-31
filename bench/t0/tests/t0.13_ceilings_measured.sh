#!/usr/bin/env bash
# T0.13 — every memory ceiling cites the measurement it came from.
# Input:  a clean checkout; no running stack required.
# Expect: zero unsourced mem_limit declarations, and every uncapped service
#         says in a comment that being uncapped is deliberate.
# Baseline expectation: XFAIL. v0.0.3 set 21 ceilings from reasoning and two of
#         them turned out to sit below the footprint the service needed, in the
#         release whose subject was honesty about resources. Flips when the
#         tiers are measured (#23) and each ceiling carries its number.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.13"

linter="$(dirname "${BASH_SOURCE[0]}")/../lib/ceilings.py"

output="$(python3 "$linter" "$NS_REPO" 2>&1)"
status=$?

while IFS= read -r line; do
    [[ -n "$line" ]] && ns_observe "$line"
done <<<"$output"

if (( status == 0 )); then
    ns_finish "$NS_OK" "every memory ceiling cites a measurement"
fi
if (( status != 1 )); then
    ns_finish "$NS_SKIP" "ceilings linter could not run (exit ${status})"
fi

count="$(printf '%s\n' "$output" | grep -cE '^\s+docker-compose' || true)"
ns_finish "$NS_KO" "${count} ceiling(s) with no measurement behind them"
