#!/usr/bin/env bash
# T0.7 — Trino can actually query the operational source (finding P-2).
# Input:  a running Trino.
# Expect: SHOW CATALOGS lists 'postgresql' and a count over
#         postgresql.public.orders returns more than zero rows.
# Baseline expectation: XFAIL — ./trino/catalog does not exist in the
# repository, so Trino starts with system catalogs only. Flips in v0.0.3.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.7"

ns_require_containers "$NS_C_TRINO"

catalogs="$(docker exec "$NS_C_TRINO" trino --execute "SHOW CATALOGS" 2>&1)"
ns_observe "catalogs: $(printf '%s' "$catalogs" | tr '\n' ' ')"

if ! printf '%s' "$catalogs" | grep -qi '"postgresql"'; then
    ns_finish "$NS_KO" "catalog 'postgresql' not registered in Trino (P-2)"
fi

# Keep stderr out of the parsed value. Trino's CLI emits a jline WARNING on
# stderr whose timestamp survives `tr -dc '0-9'` as a large positive integer:
# merging the streams and stripping non-digits off the first line made this
# assertion unable to fail -- a query returning 0 still scored OK. Observed on
# ENV-W, 2026-08-28. Diagnostics are still reported, just not parsed.
count_err="$(mktemp)"
count_stdout="$(docker exec "$NS_C_TRINO" trino --execute "SELECT count(*) FROM postgresql.public.orders" 2>"$count_err")"
count_stderr="$(cat "$count_err")"
rm -f "$count_err"
ns_observe "count stdout: $(printf '%s' "$count_stdout" | tr '\n' ' ')"
if [[ -n "$count_stderr" ]]; then
    ns_observe "count stderr: $(printf '%s' "$count_stderr" | tr '\n' ' ')"
fi

# Accept only a line that is a bare integer once the CLI's quoting is removed.
# A result row looks like "13755"; anything else on the line means this is not
# the result. Requiring exactly one such line keeps the test honest if the
# output format ever grows a header or a second row.
mapfile -t count_rows < <(printf '%s\n' "$count_stdout" | tr -d '"' | grep -Ex '[0-9]+')
if (( ${#count_rows[@]} != 1 )); then
    ns_finish "$NS_KO" "no single numeric result row in Trino output (P-2)"
fi

count="${count_rows[0]}"
if (( count > 0 )); then
    ns_finish "$NS_OK" "Trino queried postgresql.public.orders (${count} rows)"
fi
ns_finish "$NS_KO" "Trino counted ${count} rows in postgresql.public.orders (P-2)"
