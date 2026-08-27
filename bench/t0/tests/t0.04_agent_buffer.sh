#!/usr/bin/env bash
# T0.4 — the agent sees the same sentinel row in its live buffer.
# Input:  the T0.3 sentinel row (this test injects its own copy).
# Expect: GET /events?limit=50 contains 77.31 within NS_AGENT_TIMEOUT seconds.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.4"

ns_require_containers "$NS_C_POSTGRES" "$NS_C_AGENT"

ns_cleanup_sentinels
trap ns_cleanup_sentinels EXIT

ns_insert_sensor_row "$NS_SENTINEL_SITE" "$NS_SENTINEL_TEMP" "$NS_SENTINEL_VIB" "false" >/dev/null
ns_observe "sentinel row inserted (temperature_c=${NS_SENTINEL_TEMP})"

start="$(ns_now)"
deadline=$((start + NS_AGENT_TIMEOUT))
while (( $(ns_now) < deadline )); do
    if ns_curl_json "$NS_AGENT_URL/events?limit=50" 2>/dev/null | grep -q "$NS_SENTINEL_TEMP"; then
        elapsed=$(( $(ns_now) - start ))
        ns_observe "sentinel visible in /events after ${elapsed}s"
        ns_finish "$NS_OK" "agent buffered the sentinel in ${elapsed}s"
    fi
    sleep 3
done

buffered="$(ns_curl_json "$NS_AGENT_URL/health" 2>/dev/null | ns_json_get "['buffered_events']")"
ns_observe "buffered_events reported by /health: ${buffered:-unknown}"
ns_finish "$NS_KO" "sentinel ${NS_SENTINEL_TEMP} absent from /events after ${NS_AGENT_TIMEOUT}s"
