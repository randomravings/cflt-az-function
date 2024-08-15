#!/bin/bash
docker exec broker kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic success-responses