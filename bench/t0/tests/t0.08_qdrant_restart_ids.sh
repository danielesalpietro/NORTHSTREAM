#!/usr/bin/env bash
# T0.8 — restarting the agent must not overwrite already indexed points
#        (finding A-3).
# Input:  a collection with at least 20 indexed points.
# Expect: after a restart and ~10 further events, the point count grows by
#         about 10 AND every sampled pre-existing point still carries the
#         payload it had before the restart.
# Baseline expectation: XFAIL — the point id is an in-RAM counter restarting
# from zero against a persistent volume. Flips in v0.0.4.
#
# Both halves are asserted, and they answer different questions. Growth alone
# says new events land somewhere; it does not say WHERE. Comparing the set of
# ids before and after says nothing at all, because an overwritten id is still
# present -- that is precisely how A-3 hid for weeks behind a flat count. The
# assertion that discriminates is the payload of a known id: if the point that
# held event X now holds event Y, it was overwritten.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.8"

ns_require_containers "$NS_C_QDRANT" "$NS_C_AGENT"

collection="stream_events"
new_events=10

point_count() {
    ns_curl_json "$NS_QDRANT_URL/collections/${collection}" 2>/dev/null | ns_json_get "['result']['points_count']"
}

# Ids are unsigned integers today and UUID strings after the A-3 fix, so the
# sample is written as "<id>\t<sha1 of payload text>" and never parsed as a
# number. 200 points is a sample, not the whole collection: it is enough to
# catch an overwrite that walks the collection from the beginning, which is the
# shape A-3 has.
sample_points() {
    ns_post_json "$NS_QDRANT_URL/collections/${collection}/points/scroll" \
        '{"limit": 200, "with_payload": true, "with_vector": false}' 2>/dev/null |
        python3 -c "
import hashlib, json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for point in doc.get('result', {}).get('points', []):
    text = (point.get('payload') or {}).get('text', '')
    print('%s\t%s' % (point.get('id'), hashlib.sha1(text.encode()).hexdigest()))
"
}

# Re-reads exactly the sampled ids and reports how many still carry the same
# payload. A vanished point counts as changed: it is not evidence of health.
still_intact() {  # $1 = file with "<id>\t<hash>" lines
    python3 - "$1" "$NS_QDRANT_URL" "$collection" <<'PYEOF'
import hashlib, json, sys, urllib.request

path, base, collection = sys.argv[1], sys.argv[2], sys.argv[3]
want = {}
for line in open(path):
    pid, _, digest = line.rstrip("\n").partition("\t")
    if pid:
        want[pid] = digest
ids = [int(p) if p.isdigit() else p for p in want]
body = json.dumps({"ids": ids, "with_payload": True, "with_vector": False}).encode()
req = urllib.request.Request(f"{base}/collections/{collection}/points",
                             data=body, headers={"Content-Type": "application/json"})
try:
    doc = json.loads(urllib.request.urlopen(req, timeout=30).read())
except Exception as exc:
    print("ERROR %s" % exc)
    sys.exit(0)
intact = 0
for point in doc.get("result", []):
    text = (point.get("payload") or {}).get("text", "")
    if want.get(str(point.get("id"))) == hashlib.sha1(text.encode()).hexdigest():
        intact += 1
print("%d %d" % (intact, len(want)))
PYEOF
}

# Wait until the collection holds enough points to make the assertion meaningful.
deadline=$(( $(ns_now) + NS_INDEX_TIMEOUT ))
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

points_before="$(mktemp)"
sample_points | sort >"$points_before"
sampled="$(wc -l <"$points_before")"
ns_observe "sampled ${sampled} existing points with their payloads"

docker restart "$NS_C_AGENT" >/dev/null
ns_observe "agent restarted"

# Wait for roughly new_events additional events to be produced and indexed.
deadline=$(( $(ns_now) + NS_INDEX_TIMEOUT ))
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

intact_line="$(still_intact "$points_before")"
rm -f "$points_before"

if [[ "$intact_line" == ERROR* || -z "$intact_line" ]]; then
    ns_finish "$NS_SKIP" "could not re-read the sampled points (${intact_line:-no answer}): cannot tell an overwrite from an unmeasured collection"
fi
intact="${intact_line% *}"
checked="${intact_line#* }"
ns_observe "sampled points still carrying their original payload: ${intact}/${checked}"

if (( intact < checked )); then
    ns_finish "$NS_KO" "$(( checked - intact )) of ${checked} sampled points changed payload across the restart: they were overwritten (A-3)"
fi
if (( growth < new_events - 2 )); then
    ns_finish "$NS_KO" "count grew by only ${growth} after restart: new events are landing on existing points (A-3)"
fi
ns_finish "$NS_OK" "count grew by ${growth} and all ${checked} sampled points kept their payload"
