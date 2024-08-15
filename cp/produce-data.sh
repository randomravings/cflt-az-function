#!/bin/bash
if [[ $# -ne 1 || $1 < 1 ||  $1 > 2 ]]; then
    echo "Usage '$(basename "$0") [1|2]"
    echo "  1: test-func-sink"
    echo "  2: test-http-sink"
    exit 1
fi
RECORD="{ \"hours\": ${RANDOM:0:3}, \"capacity\": ${RANDOM:0:6} }"
SCHEMA=$(jq -c . "data/samplePayload.avsc")
TOPIC="test-func-sink"
if [[ $1 -eq 2 ]]; then
    TOPIC="test-http-sink"
fi
docker exec -i schema-registry kafka-avro-console-producer \
    --bootstrap-server broker:29092 \
    --topic $TOPIC \
    --property schema.registry.url=http://localhost:8081 \
    --property value.schema="$SCHEMA" &> /dev/null << EOF
$RECORD
EOF
echo "'$RECORD' written to '$TOPIC'"