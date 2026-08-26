#!/usr/bin/env bash
# T0.10 — retrieval must find a real anomaly for a site that is not in the
#         hardcoded KNOWN_SITES list (finding A-1).
# Input:  an anomaly injected for Depot-9, a site the generator never emits.
# Expect: context_used contains the Depot-9 event.
# Baseline expectation: XFAIL — the keyword boost only covers KNOWN_SITES and
# the 30m embedding does not rank the event on semantics alone. Flips in
# v0.0.4, when the boost is replaced by a payload filter.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.10"

ns_require_containers "$NS_C_POSTGRES" "$NS_C_AGENT"

ns_cleanup_sentinels
trap ns_cleanup_sentinels EXIT

ns_insert_sensor_row "$NS_UNKNOWN_SITE" "$NS_UNKNOWN_TEMP" "1.512" "true" >/dev/null
ns_observe "anomaly injected for ${NS_UNKNOWN_SITE} (${NS_UNKNOWN_TEMP})"

deadline=$(( $(ns_now) + NS_AGENT_TIMEOUT ))
indexed="no"
while (( $(ns_now) < deadline )); do
    if ns_curl_json "$NS_AGENT_URL/events?limit=50" 2>/dev/null | grep -q "$NS_UNKNOWN_SITE"; then
        indexed="yes"
        break
    fi
    sleep 3
done
[[ "$indexed" == "yes" ]] || ns_finish "$NS_SKIP" "the ${NS_UNKNOWN_SITE} event never reached the agent"
ns_observe "event visible in the agent buffer"

question="Are there any anomalies at ${NS_UNKNOWN_SITE}?"
body="$(python3 -c 'import json,sys; print(json.dumps({"question": sys.argv[1]}))' "$question")"
response="$(ns_post_json "$NS_AGENT_URL/chat" "$body")"
[[ -n "$response" ]] || ns_finish "$NS_KO" "no response from /chat"

context="$(printf '%s' "$response" | ns_json_get "['context_used']")"
ns_observe "context_used: $(printf '%s' "$context" | head -c 400)"

if [[ "$context" == *"$NS_UNKNOWN_SITE"* ]]; then
    ns_finish "$NS_OK" "retrieval surfaced the ${NS_UNKNOWN_SITE} event"
fi
ns_finish "$NS_KO" "retrieval missed the ${NS_UNKNOWN_SITE} event: the site is outside KNOWN_SITES (A-1)"
