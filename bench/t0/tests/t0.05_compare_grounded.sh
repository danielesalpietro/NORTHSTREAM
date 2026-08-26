#!/usr/bin/env bash
# T0.5 — /compare answers the canonical demo question with both sides filled in
#        and the grounded side actually carrying the injected value.
# Input:  a known anomaly ('Plant-B', 91.73, 1.234, true).
# Expect: with/without_stream_context present and non-empty; context_used
#         contains 91.73; the grounded answer mentions 91.7.
#
# The context assertion is deterministic; the answer assertion depends on the
# model, so it is retried once (flaky-tolerated on the baseline, per plan 4.1).
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.5"

ns_require_containers "$NS_C_POSTGRES" "$NS_C_AGENT" "$NS_C_OLLAMA"

ns_cleanup_sentinels
trap ns_cleanup_sentinels EXIT

ns_insert_sensor_row "$NS_ANOMALY_SITE" "$NS_ANOMALY_TEMP" "$NS_ANOMALY_VIB" "true" >/dev/null
ns_observe "anomaly row inserted (${NS_ANOMALY_SITE}, ${NS_ANOMALY_TEMP})"

# Give the consumer time to index the event before asking about it.
deadline=$(( $(ns_now) + NS_AGENT_TIMEOUT ))
while (( $(ns_now) < deadline )); do
    ns_curl_json "$NS_AGENT_URL/events?limit=50" 2>/dev/null | grep -q "$NS_ANOMALY_TEMP" && break
    sleep 3
done

question="Are there any recent sensor anomalies at ${NS_ANOMALY_SITE}? What temperature and vibration values were recorded?"
body="$(python3 -c 'import json,sys; print(json.dumps({"question": sys.argv[1]}))' "$question")"

attempt=1
max_attempts=2
while (( attempt <= max_attempts )); do
    response="$(ns_post_json "$NS_AGENT_URL/compare" "$body")"
    if [[ -z "$response" ]]; then
        ns_observe "attempt ${attempt}: empty response from /compare"
        attempt=$((attempt + 1))
        continue
    fi

    without="$(printf '%s' "$response" | ns_json_get "['without_stream_context']")"
    with="$(printf '%s' "$response" | ns_json_get "['with_stream_context']")"
    context="$(printf '%s' "$response" | ns_json_get "['context_used']")"

    [[ -n "$without" ]] || { ns_observe "attempt ${attempt}: without_stream_context empty"; attempt=$((attempt + 1)); continue; }
    [[ -n "$with" ]] || { ns_observe "attempt ${attempt}: with_stream_context empty"; attempt=$((attempt + 1)); continue; }

    if [[ "$context" != *"$NS_ANOMALY_TEMP"* ]]; then
        ns_observe "attempt ${attempt}: context_used does not carry ${NS_ANOMALY_TEMP}"
        attempt=$((attempt + 1))
        continue
    fi
    ns_observe "context_used carries the injected value ${NS_ANOMALY_TEMP}"

    if [[ "$with" == *"91.7"* ]]; then
        ns_observe "grounded answer cites the value (attempt ${attempt})"
        ns_finish "$NS_OK" "/compare grounded on the injected anomaly (attempt ${attempt})"
    fi
    ns_observe "attempt ${attempt}: grounded answer does not cite 91.7"
    attempt=$((attempt + 1))
done

ns_finish "$NS_KO" "/compare did not produce a grounded answer citing 91.7 in ${max_attempts} attempts"
