#!/usr/bin/env bash

# Generate keys
#
# MDS requires that the keypair be in PKCS#1 format, which as of OpenSSL 3.0.0 requires the -traditional flag. Passing
# this flag to earlier versions of OpenSSL throws an error so we only pass it for OpenSSL 3.0.0 and later. See MDS
# keypair requirements here: https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#create-a-pem-key-pair
rm -fr /tmp/ext-mds/
mkdir /tmp/ext-mds/

OPENSSL_VERSION=get_version_openssl
if version_gte $OPENSSL_VERSION "3.0.0" ; then
  OPENSSL_FLAGS="-traditional"
fi
openssl genrsa -out /tmp/ext-mds/tokenKeypair.pem $OPENSSL_FLAGS 2048
openssl rsa -in /tmp/ext-mds/tokenKeypair.pem -outform PEM -pubout -out /tmp/ext-mds/tokenPublicKey.pem

# copy login.properties to /tmp
cp login.properties /tmp/ext-mds/login.properties

# USERS
USER_ADMIN_C3="c3"
USER_ADMIN_SYSTEM="MySystemAdmin"

# RUN ZOOKEEPER
echo "Starting Zookeeper..."
zookeeper-server-start zookeeper.properties > zoo.log 2>&1 &
zookeeper-server-start zookeeper.ext.properties > zoo.ext.log 2>&1 &

# RUN KAFKA
echo "Starting Kafka..."
kafka-server-start server.properties > server.log 2>&1 &
kafka-server-start server.ext.properties > server.ext.log 2>&1 &

# GET KAFKA CLUSTER ID
echo "Wait for the broker to start..."
sleep 60
echo "Getting Kafka Cluster ID..."
export CONFLUENT_USERNAME=mds
export CONFLUENT_PASSWORD=mds1
confluent login --url http://localhost:8090 
KAFKA_CLUSTER_ID=$(curl -s http://localhost:8090/v1/metadata/id | jq -r ".id")
echo "Kafka Cluster ID: $KAFKA_CLUSTER_ID"

# CREATE ROLE-BINDINGS
echo "Creating role-bindings..."
confluent iam rbac role-binding create --principal User:$USER_ADMIN_SYSTEM --role SystemAdmin --kafka-cluster $KAFKA_CLUSTER_ID
confluent iam rbac role-binding create --principal User:$USER_ADMIN_C3 --role SystemAdmin --kafka-cluster $KAFKA_CLUSTER_ID

# CREATE ROLE-BINDINGS ON CLUSTER 2
export CONFLUENT_USERNAME=mds
export CONFLUENT_PASSWORD=mds1
confluent login --url http://localhost:8091
KAFKA_CLUSTER_ID=$(curl -s http://localhost:8091/v1/metadata/id | jq -r ".id")
echo "Creating role-bindings..."
confluent iam rbac role-binding create --principal User:$USER_ADMIN_SYSTEM --role SystemAdmin --kafka-cluster $KAFKA_CLUSTER_ID
confluent iam rbac role-binding create --principal User:$USER_ADMIN_C3 --role SystemAdmin --kafka-cluster $KAFKA_CLUSTER_ID

# RUN C3
echo "Starting Control Center..."
control-center-start control-center-dev.properties > c3.log 2>&1 &