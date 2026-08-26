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

count_output="$(docker exec "$NS_C_TRINO" trino --execute "SELECT count(*) FROM postgresql.public.orders" 2>&1)"
ns_observe "count query output: $(printf '%s' "$count_output" | tr '\n' ' ')"

count="$(printf '%s' "$count_output" | tr -d '"' | head -1 | tr -dc '0-9')"
if [[ -n "$count" ]] && (( count > 0 )); then
    ns_finish "$NS_OK" "Trino queried postgresql.public.orders (${count} rows)"
fi
ns_finish "$NS_KO" "Trino could not count rows in postgresql.public.orders (P-2)"
