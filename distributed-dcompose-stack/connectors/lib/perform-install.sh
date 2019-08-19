#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")/.."

. ../../commons/lib/util.sh

echo "OS version: $(uname -a)"
check_command_exists docker
check_command_exists docker-compose

echo "==> Configuring MongoDB Connector"
# Update sink-mongo.properties
ensure_variable 'mongo.username=' $HOTSTORAGE_USERNAME etc/mongodb-connector/sink-mongo.properties
ensure_variable 'mongo.password=' $HOTSTORAGE_PASSWORD etc/mongodb-connector/sink-mongo.properties
ensure_variable 'mongo.database=' $HOTSTORAGE_NAME etc/mongodb-connector/sink-mongo.properties

echo "==> Configuring Fitbit Connector"
ensure_variable 'fitbit.api.client=' $FITBIT_API_CLIENT_ID etc/fitbit/docker/source-fitbit.properties
ensure_variable 'fitbit.api.secret=' $FITBIT_API_CLIENT_SECRET etc/fitbit/docker/source-fitbit.properties

KAFKA_INIT_OPTS=(
    --rm -v "$PWD/etc/schema:/schema/conf"
    radarbase/kafka-init:${RADAR_SCHEMAS_VERSION}
  )

# Set topics
if [ -z "${COMBINED_AGG_TOPIC_LIST}"]; then
  COMBINED_AGG_TOPIC_LIST=$(sudo-linux docker run "${KAFKA_INIT_OPTS[@]}" list_aggregated.sh 2>/dev/null | tail -n 1)
  if [ -n "${RADAR_AGG_TOPIC_LIST}" ]; then
    COMBINED_AGG_TOPIC_LIST="${RADAR_AGG_TOPIC_LIST},${COMBINED_AGG_TOPIC_LIST}"
  fi
fi
ensure_variable 'topics=' "${COMBINED_AGG_TOPIC_LIST}" etc/mongodb-connector/sink-mongo.properties

echo "==> Configuring HDFS Connector"
if [ -z "${COMBINED_RAW_TOPIC_LIST}"]; then
  COMBINED_RAW_TOPIC_LIST=$(sudo-linux docker run "${KAFKA_INIT_OPTS[@]}" list_raw.sh 2>/dev/null | tail -n 1)
  if [ -n "${RADAR_RAW_TOPIC_LIST}" ]; then
    COMBINED_RAW_TOPIC_LIST="${RADAR_RAW_TOPIC_LIST},${COMBINED_RAW_TOPIC_LIST}"
  fi
fi
ensure_variable 'topics=' "${COMBINED_RAW_TOPIC_LIST}" etc/hdfs-connector/sink-hdfs.properties

sudo-linux docker-compose up -d
