#!/usr/bin/env bash

control-center-stop
kafka-server-stop
zookeeper-server-stop

rm -fr /tmp/ext-mds/