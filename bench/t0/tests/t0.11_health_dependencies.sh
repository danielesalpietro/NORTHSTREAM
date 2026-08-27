#!/usr/bin/env bash
# T0.11 — /health must be able to fail (finding A-5).
# Input:  the agent up, Qdrant stopped.
# Expect: status different from "ok", or a dependencies block reporting
#         qdrant as down.
# Baseline expectation: XFAIL — /health returns "ok" unconditionally.
# Flips in v0.0.4. Qdrant is always restarted, whatever the outcome.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.11"

ns_require_containers "$NS_C_AGENT" "$NS_C_QDRANT"

restore_qdrant() {
    docker start "$NS_C_QDRANT" >/dev/null 2>&1 || true
    # Give the agent a moment to reconnect before the next test runs.
    sleep 5
}
trap restore_qdrant EXIT

docker stop "$NS_C_QDRANT" >/dev/null
ns_observe "qdrant stopped"
sleep 5

response="$(ns_curl_json "$NS_AGENT_URL/health" 2>/dev/null)"
if [[ -z "$response" ]]; then
    ns_observe "/health did not answer at all: the agent is down, not degraded"
    ns_finish "$NS_KO" "/health unreachable while qdrant is down"
fi
ns_observe "/health response: $(printf '%s' "$response" | head -c 300)"

status="$(printf '%s' "$response" | ns_json_get "['status']")"
has_dependencies="$(printf '%s' "$response" | ns_json_contains "dependencies")"
qdrant_down="$(printf '%s' "$response" | python3 -c "
import json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    print('no'); raise SystemExit
deps = doc.get('dependencies') or {}
value = str(deps.get('qdrant', '')).lower()
print('yes' if value and value not in ('ok', 'up', 'true', 'healthy') else 'no')
" 2>/dev/null)"

ns_observe "status='${status}' dependencies_present=${has_dependencies} qdrant_reported_down=${qdrant_down}"

if [[ "$status" != "ok" || "$qdrant_down" == "yes" ]]; then
    ns_finish "$NS_OK" "/health reflects the failed dependency"
fi
ns_finish "$NS_KO" "/health still reports ok with qdrant down (A-5)"
