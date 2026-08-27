#!/usr/bin/env bash
# T0.3 — a sentinel row inserted in Postgres reaches its Kafka topic as plain
#        JSON (not base64) within the CDC budget.
# Input:  INSERT ... VALUES ('Plant-A', 77.31, 0.411, false)
# Expect: a message on northstream.public.sensor_readings carrying
#         "temperature_c":77.31 as a number.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ns_init "T0.3"

ns_require_containers "$NS_C_KAFKA" "$NS_C_POSTGRES" "$NS_C_CONNECT"

topic="northstream.public.sensor_readings"

connector_state="$(ns_curl_json "$NS_CONNECT_URL/connectors/northstream-postgres-connector/status" 2>/dev/null | ns_json_get "['connector']['state']")"
if [[ "$connector_state" != "RUNNING" ]]; then
    ns_finish "$NS_SKIP" "CDC connector not RUNNING (state='${connector_state:-absent}'): register it first"
fi
ns_observe "connector state: RUNNING"

ns_cleanup_sentinels
trap ns_cleanup_sentinels EXIT

consume_log="$(mktemp)"
# The consumer is bounded by wall clock, not by --timeout-ms: with the data
# generator running there is always another message within a few seconds, so
# an idle timeout would never fire and the test would hang.
#
# Absolute path first, bare name as fallback: apache/kafka (#17) ships
# kafka-console-consumer.sh under /opt/kafka/bin/ but does not put it on
# PATH, unlike the bitnamilegacy image this test was written against.
docker exec "$NS_C_KAFKA" sh -c \
    "cmd=kafka-console-consumer.sh; [ -x /opt/kafka/bin/kafka-console-consumer.sh ] && cmd=/opt/kafka/bin/kafka-console-consumer.sh; timeout ${NS_CDC_TIMEOUT} \"\$cmd\" --bootstrap-server kafka:9092 --topic ${topic} 2>>/tmp/t0.3-consumer.err" \
    >"$consume_log" &
consumer_pid=$!
sleep 5

ns_insert_sensor_row "$NS_SENTINEL_SITE" "$NS_SENTINEL_TEMP" "$NS_SENTINEL_VIB" "false" >/dev/null
ns_observe "sentinel row inserted (temperature_c=${NS_SENTINEL_TEMP})"

wait "$consumer_pid" 2>/dev/null || true

if grep -q "\"temperature_c\":${NS_SENTINEL_TEMP}" "$consume_log"; then
    ns_observe "sentinel found on ${topic} as a JSON number"
    rm -f "$consume_log"
    ns_finish "$NS_OK" "CDC delivered temperature_c=${NS_SENTINEL_TEMP} within ${NS_CDC_TIMEOUT}s"
fi

if grep -q "temperature_c" "$consume_log"; then
    sample="$(grep -o '"temperature_c":[^,}]*' "$consume_log" | head -1)"
    ns_observe "topic carries temperature_c but not as the expected number: ${sample}"
fi
ns_observe "messages captured: $(wc -l <"$consume_log")"
consumer_err="$(docker exec "$NS_C_KAFKA" sh -c 'tail -3 /tmp/t0.3-consumer.err 2>/dev/null' | tr '\n' ' ')"
[[ -n "$consumer_err" ]] && ns_observe "consumer stderr: ${consumer_err}"
rm -f "$consume_log"
ns_finish "$NS_KO" "sentinel ${NS_SENTINEL_TEMP} not observed on ${topic} within ${NS_CDC_TIMEOUT}s"
