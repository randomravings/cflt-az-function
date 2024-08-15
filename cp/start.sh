#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "Usage '$(basename "$0") <app-name> <function-key>'"
    exit 1
fi

docker compose down -v

docker compose up -d

echo "Waiting Broker UP..."
FOUND=''
while [[ $FOUND != "yes" ]]; do
  sleep 1
  FOUND=$(docker exec broker /bin/kafka-cluster cluster-id --bootstrap-server localhost:9092 &>/dev/null && echo 'yes')
done
echo "Broker ready!!"

echo "Creating topics..."
docker exec broker kafka-topics --bootstrap-server localhost:9092 --topic test-func-sink --create --partitions 1 --replication-factor 1
docker exec broker kafka-topics --bootstrap-server localhost:9092 --topic test-http-sink --create --partitions 1 --replication-factor 1

echo "Waiting Schema Registry UP..."
FOUND=''
while [[ $FOUND != "200" ]]; do
  sleep 1
  FOUND=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/)
done
echo "Schema Registry ready!!"

echo "Creating schemas..."
SCHEMA=$(jq -c . "data/samplePayload.avsc")
DATA=$(jq --arg data "$SCHEMA" '.schema = $data' "data/subject.json")
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" --data "$DATA" http://localhost:8081/subjects/test-func-sink-value/versions | jq .
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" --data "$DATA" http://localhost:8081/subjects/test-http-sink-value/versions | jq .

echo "Waiting Connect UP..."
FOUND=''
while [[ $FOUND != "200" ]]; do
  sleep 1
  FOUND=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/)
done
echo "Connect ready!!"

echo "Installing connectors..."
docker exec -i connect confluent-hub install confluentinc/kafka-connect-http:latest --component-dir /usr/share/java --no-prompt
docker exec -i connect confluent-hub install confluentinc/kafka-connect-azure-functions:latest --component-dir /usr/share/java --no-prompt
docker compose restart connect

echo "Waiting Connect UP..."
FOUND=''
while [[ $FOUND != "200" ]]; do
  sleep 1
  FOUND=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/)
done
echo "Connect ready!!"

echo "Deploying connectors..."
DATA=$(jq --arg fa $1 --arg fk $2 '."function.url"|=gsub("<app>"; $fa)|."function.key"|=gsub("<key>";$fk)' "data/connect-azfn-sink.json")
curl -X PUT  -H 'Content-Type: application/json' --data "$DATA" http://localhost:8083/connectors/az-func-sink/config | jq .
DATA=$(jq --arg fa $1 --arg fk $2 '."http.api.url"|=gsub("<app>";$fa)|.headers|=gsub("<key>";$fk)' "data/connect-http-sink.json")
curl -X PUT  -H 'Content-Type: application/json' --data "$DATA" http://localhost:8083/connectors/az-http-sink/config | jq .

echo "Done!!"

# show result
docker-compose ps -a

