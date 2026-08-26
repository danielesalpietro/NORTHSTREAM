#!/usr/bin/env bash
# T0.9 — a question about recent anomalies must not be answered with a stale
#        event (finding A-2).
# Input:  one anomaly indexed, then the generator stopped and the recency
#         threshold (NS_RECENCY_SECONDS) allowed to elapse.
# Expect: the retrieved context carries no event older than the threshold and
#         the answer does not cite the stale anomaly.
# Baseline expectation: XFAIL — Qdrant payloads carry no timestamp, so nothing
# can filter by age. Flips in v0.0.4.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.9"

ns_require_containers "$NS_C_POSTGRES" "$NS_C_AGENT"

ns_cleanup_sentinels
restore_generator() {
    ns_cleanup_sentinels
    if ns_have_docker && docker inspect "$NS_C_GENERATOR" >/dev/null 2>&1; then
        docker start "$NS_C_GENERATOR" >/dev/null 2>&1 || true
    fi
}
trap restore_generator EXIT

ns_insert_sensor_row "$NS_ANOMALY_SITE" "$NS_ANOMALY_TEMP" "$NS_ANOMALY_VIB" "true" >/dev/null
ns_observe "stale anomaly injected (${NS_ANOMALY_TEMP})"

deadline=$(( $(ns_now) + NS_AGENT_TIMEOUT ))
indexed="no"
while (( $(ns_now) < deadline )); do
    if ns_curl_json "$NS_AGENT_URL/events?limit=50" 2>/dev/null | grep -q "$NS_ANOMALY_TEMP"; then
        indexed="yes"
        break
    fi
    sleep 3
done
[[ "$indexed" == "yes" ]] || ns_finish "$NS_SKIP" "the anomaly never reached the agent: nothing to age out"

if docker inspect "$NS_C_GENERATOR" >/dev/null 2>&1; then
    docker stop "$NS_C_GENERATOR" >/dev/null 2>&1 || true
    ns_observe "data generator stopped"
fi

ns_observe "waiting ${NS_RECENCY_SECONDS}s for the event to become stale"
sleep "$NS_RECENCY_SECONDS"

minutes=$(( NS_RECENCY_SECONDS / 60 ))
(( minutes < 1 )) && minutes=1
question="Any anomalies in the last ${minutes} minutes?"
body="$(python3 -c 'import json,sys; print(json.dumps({"question": sys.argv[1]}))' "$question")"
response="$(ns_post_json "$NS_AGENT_URL/chat" "$body")"

[[ -n "$response" ]] || ns_finish "$NS_KO" "no response from /chat"

context="$(printf '%s' "$response" | ns_json_get "['context_used']")"
answer="$(printf '%s' "$response" | ns_json_get "['answer']")"
ns_observe "context_used: $(printf '%s' "$context" | head -c 400)"

if [[ "$context" == *"$NS_ANOMALY_TEMP"* ]]; then
    ns_observe "the stale anomaly is still in the retrieved context"
    ns_finish "$NS_KO" "context carries an event older than ${NS_RECENCY_SECONDS}s (A-2)"
fi

if [[ "$answer" == *"$NS_ANOMALY_TEMP"* || "$answer" == *"91.7"* ]]; then
    ns_finish "$NS_KO" "the answer cites the stale anomaly (A-2)"
fi

ns_finish "$NS_OK" "no event older than ${NS_RECENCY_SECONDS}s in context or answer"
