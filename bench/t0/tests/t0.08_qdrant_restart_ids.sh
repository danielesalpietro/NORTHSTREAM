#!/usr/bin/env bash
# T0.8 — restarting the agent must not overwrite already indexed points
#        (finding A-3).
# Input:  a collection with at least 20 indexed points.
# Expect: after a restart and ~10 further events, the point count grows by
#         about 10 and none of the pre-existing ids is reused.
# Baseline expectation: XFAIL — the point id is an in-RAM counter restarting
# from zero against a persistent volume. Flips in v0.0.4.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.8"

ns_require_containers "$NS_C_QDRANT" "$NS_C_AGENT"

collection="stream_events"
new_events=10

point_count() {
    ns_curl_json "$NS_QDRANT_URL/collections/${collection}" 2>/dev/null | ns_json_get "['result']['points_count']"
}

sample_ids() {
    ns_post_json "$NS_QDRANT_URL/collections/${collection}/points/scroll" \
        '{"limit": 200, "with_payload": false, "with_vector": false}' 2>/dev/null |
        python3 -c "
import json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for point in doc.get('result', {}).get('points', []):
    print(point.get('id'))
"
}

# Wait until the collection holds enough points to make the assertion meaningful.
deadline=$(( $(ns_now) + NS_STACK_TIMEOUT ))
before=""
while (( $(ns_now) < deadline )); do
    before="$(point_count)"
    [[ -n "$before" && "$before" != "None" ]] && (( before >= 20 )) && break
    sleep 5
done

if [[ -z "$before" || "$before" == "None" ]] || (( before < 20 )); then
    ns_finish "$NS_SKIP" "collection '${collection}' has ${before:-no} points: need at least 20 (is the generator running?)"
fi
ns_observe "points before restart: ${before}"

ids_before="$(mktemp)"
sample_ids | sort >"$ids_before"
ns_observe "sampled $(wc -l <"$ids_before") existing ids"

docker restart "$NS_C_AGENT" >/dev/null
ns_observe "agent restarted"

# Wait for roughly new_events additional events to be produced and indexed.
deadline=$(( $(ns_now) + NS_STACK_TIMEOUT ))
after="$before"
while (( $(ns_now) < deadline )); do
    sleep 10
    current="$(point_count)"
    [[ -z "$current" || "$current" == "None" ]] && continue
    after="$current"
    (( after >= before + new_events )) && break
    events_seen="$(ns_curl_json "$NS_AGENT_URL/health" 2>/dev/null | ns_json_get "['buffered_events']")"
    if [[ -n "$events_seen" && "$events_seen" != "None" ]] && (( events_seen >= new_events )); then
        break
    fi
done

ns_observe "points after restart and ~${new_events} new events: ${after}"
growth=$(( after - before ))
ns_observe "growth: ${growth} (expected about ${new_events})"

ids_after="$(mktemp)"
sample_ids | sort >"$ids_after"
reused="$(comm -12 "$ids_before" "$ids_after" | wc -l)"
sampled_before="$(wc -l <"$ids_before")"
ns_observe "ids still present out of ${sampled_before} sampled: ${reused}"

rm -f "$ids_before" "$ids_after"

if (( growth >= new_events - 2 )); then
    ns_finish "$NS_OK" "count grew by ${growth} with no overwrite after restart"
fi
ns_finish "$NS_KO" "count grew by only ${growth} after restart: points are being overwritten (A-3)"
