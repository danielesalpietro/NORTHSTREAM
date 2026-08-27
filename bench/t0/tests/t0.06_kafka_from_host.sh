#!/usr/bin/env bash
# T0.6 — a client outside the Docker network can use the advertised bootstrap
#        endpoint (finding P-1).
# Input:  localhost:9092 as documented by the README services table.
# Expect: full broker metadata within 15 s.
# Baseline expectation: XFAIL — the broker advertises PLAINTEXT://kafka:9092,
# a name that does not resolve on the host. Flips in v0.0.2 (dual listener).
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.6"

ns_require_containers "$NS_C_KAFKA"

host="${NS_KAFKA_HOST_BOOTSTRAP%%:*}"
port="${NS_KAFKA_HOST_BOOTSTRAP##*:}"

metadata=""
probe_status=""

if command -v kcat >/dev/null 2>&1; then
    ns_observe "probing with local kcat"
    metadata="$(timeout 15 kcat -b "$NS_KAFKA_HOST_BOOTSTRAP" -L 2>&1)"
    probe_status=$?
elif python3 -c "import kafka" >/dev/null 2>&1; then
    ns_observe "probing with kafka-python from the host"
    metadata="$(timeout 15 python3 -c "
from kafka import KafkaConsumer
c = KafkaConsumer(bootstrap_servers='${NS_KAFKA_HOST_BOOTSTRAP}', api_version_auto_timeout_ms=10000, request_timeout_ms=10000)
print('brokers:', c.bootstrap_connected())
print('topics:', sorted(c.topics()))
" 2>&1)"
    probe_status=$?
elif ns_have_docker; then
    ns_observe "probing with kcat in a host-network container"
    metadata="$(timeout 60 docker run --rm --network host edenhill/kcat:1.7.1 -b "$NS_KAFKA_HOST_BOOTSTRAP" -L 2>&1)"
    probe_status=$?
else
    ns_finish "$NS_SKIP" "no host-side Kafka client available (kcat, kafka-python or docker)"
fi

ns_observe "probe exit status: ${probe_status}"
ns_observe "probe output (first lines): $(printf '%s' "$metadata" | head -3 | tr '\n' ' ')"

# Usable metadata must name a broker the host can actually reach.
if (( probe_status == 0 )) && printf '%s' "$metadata" | grep -Eq "${host}:${port}|topics:"; then
    if printf '%s' "$metadata" | grep -q "kafka:9092"; then
        ns_observe "metadata advertises the in-network name kafka:9092: unusable from the host"
        ns_finish "$NS_KO" "bootstrap returns unreachable metadata (P-1)"
    fi
    ns_finish "$NS_OK" "host client obtained usable broker metadata from ${NS_KAFKA_HOST_BOOTSTRAP}"
fi

ns_finish "$NS_KO" "host client could not use ${NS_KAFKA_HOST_BOOTSTRAP} (P-1)"
