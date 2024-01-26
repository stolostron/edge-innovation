#!/usr/bin/env bash

REPO_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/.." ; pwd -P)"

demo_dir=${REPO_DIR}/sensor-aggregator
kubeconfig=${REPO_DIR}/_output/clusters/edge-demo-kind.kubeconfig

cluster="edge"

source ${demo_dir}/demo_magic

export KUBECONFIG=${kubeconfig}
comment "An edge cluster is managed by ACM hub as a managed cluster"
pe "kubectl get managedclusters"

comment "A managedclusteraddon (Sensor Aggregator) is deployed on the edge cluster"
comment "It is used to collect data from IoT devices/sensors"
pe "kubectl -n ${cluster} get managedclusteraddons"

comment "A opcua server is running on the edge cluster to simulate opcua device"
pe "kubectl -n opcua-server get svc"

comment "Enable the opcua driver on the ACM hub"
pe "kubectl -n ${cluster} apply -f ${demo_dir}/resources/opcua/driver.yaml"
pe "kubectl -n ${cluster} get drivers.edge.open-cluster-management.io"

comment "Add the simulated opcua device on the ACM hub"
pe "kubectl -n ${cluster} apply -f ${demo_dir}/resources/opcua/device.yaml"
pe "kubectl -n ${cluster} get devices opcua-s001 -oyaml"

comment "The sensor aggregator has a build-in MQTT broker on the edge cluster by default"
pe "kubectl -n open-cluster-management-agent-addon get svc"

comment "You can receive the data of device opcua-s001 with MQTT topic devices/+/data/+ on tcp://127.0.0.1:1883"
comment "e.g. mosquitto_sub -h 127.0.0.1 -p 1883 -t devices/+/data/+"

unset KUBECONFIG
