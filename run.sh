#!/usr/bin/env bash

# Generate keys
#
# MDS requires that the keypair be in PKCS#1 format, which as of OpenSSL 3.0.0 requires the -traditional flag. Passing
# this flag to earlier versions of OpenSSL throws an error so we only pass it for OpenSSL 3.0.0 and later. See MDS
# keypair requirements here: https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#create-a-pem-key-pair
OPENSSL_VERSION=get_version_openssl
if version_gte $OPENSSL_VERSION "3.0.0" ; then
  OPENSSL_FLAGS="-traditional"
fi
openssl genrsa -out /tmp/tokenKeypair.pem $OPENSSL_FLAGS 2048
openssl rsa -in /tmp/tokenKeypair.pem -outform PEM -pubout -out /tmp/tokenPublicKey.pem

# copy login.properties to /tmp
cp login.properties /tmp/login.properties

# USERS
USER_ADMIN_C3="c3"
USER_ADMIN_SYSTEM="MySystemAdmin"

# RUN ZOOKEEPER
zookeeper-server-start zookeeper.properties > zoo.log 2>&1 &

# RUN KAFKA
kafka-server-start server.properties > server.log 2>&1 &

# GET KAFKA CLUSTER ID
sleep 10
KAFKA_CLUSTER_ID=$(curl -s http://localhost:8090/v1/metadata/id | jq -r ".id")


# CREATE ROLE-BINDINGS
confluent iam rbac role-binding create --principal User:$USER_ADMIN_SYSTEM --role SystemAdmin --kafka-cluster $KAFKA_CLUSTER_ID
confluent iam rbac role-binding create --principal User:$USER_ADMIN_C3 --role SystemAdmin --kafka-cluster $KAFKA_CLUSTER_ID

# RUN C3
control-center-start control-center-dev.properties > c3.log 2>&1 &