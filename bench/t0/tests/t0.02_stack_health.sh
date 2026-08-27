#!/usr/bin/env bash
# T0.2 — the started stack becomes reachable within the declared budget.
# Input:  base+addon stack already started by the caller.
# Expect: Kafka, Postgres, Connect, Qdrant, Ollama and the agent all answer
#         within NS_STACK_TIMEOUT seconds; the elapsed time is recorded.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.2"

ns_require_containers "$NS_C_KAFKA" "$NS_C_POSTGRES" "$NS_C_CONNECT" \
    "$NS_C_QDRANT" "$NS_C_OLLAMA" "$NS_C_AGENT"

start="$(ns_now)"
deadline=$((start + NS_STACK_TIMEOUT))

# Plain `sh -c`, exactly like the compose healthcheck. Absolute path first:
# apache/kafka (#17) ships kafka-topics.sh under /opt/kafka/bin/ but does not
# put it on PATH, unlike the bitnamilegacy image this test was written
# against. The bare-name fallbacks keep this working against an image that
# does put it on PATH.
probe_kafka() {
    docker exec "$NS_C_KAFKA" sh -c \
        '/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list >/dev/null 2>&1 || kafka-topics.sh --bootstrap-server kafka:9092 --list >/dev/null 2>&1 || kafka-topics --bootstrap-server kafka:9092 --list >/dev/null 2>&1'
}
probe_postgres() { docker exec "$NS_C_POSTGRES" pg_isready -U demo -d sales >/dev/null 2>&1; }
probe_connect()  { ns_curl_json "$NS_CONNECT_URL/connectors" >/dev/null 2>&1; }
probe_qdrant()   { ns_curl_json "$NS_QDRANT_URL/collections" >/dev/null 2>&1; }
probe_ollama()   { docker exec "$NS_C_AGENT" python -c "
import os, urllib.request
urllib.request.urlopen(os.environ.get('OLLAMA_BASE_URL', 'http://ollama:11434') + '/api/tags', timeout=5)
" >/dev/null 2>&1; }
probe_agent()    { ns_curl_json "$NS_AGENT_URL/health" >/dev/null 2>&1; }

services="kafka postgres connect qdrant ollama agent"
pending="$services"

while [[ -n "$pending" ]] && (( $(ns_now) < deadline )); do
    still_pending=""
    for svc in $pending; do
        if "probe_${svc}"; then
            ns_observe "$svc reachable after $(( $(ns_now) - start ))s"
        else
            still_pending="$still_pending $svc"
        fi
    done
    pending="$(echo "$still_pending" | xargs || true)"
    [[ -n "$pending" ]] && sleep 5
done

elapsed=$(( $(ns_now) - start ))
if [[ -z "$pending" ]]; then
    ns_observe "all services reachable in ${elapsed}s (budget ${NS_STACK_TIMEOUT}s)"
    ns_finish "$NS_OK" "stack reachable in ${elapsed}s"
fi
ns_finish "$NS_KO" "not reachable within ${NS_STACK_TIMEOUT}s: $pending"
