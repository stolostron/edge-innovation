#!/bin/bash

CURRENT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/." ; pwd -P)"

observability_repo=${CURRENT_DIR}/_output/multicluster-observability-operator

rm -rf ${CURRENT_DIR}/_output

mkdir -p ${observability_repo}

git clone --depth=1 https://github.com/stolostron/multicluster-observability-operator.git ${observability_repo}

oc create ns open-cluster-management-observability

oc apply -k ${observability_repo}/examples/minio
oc apply -f ${observability_repo}/operators/multiclusterobservability/config/samples/observability_v1beta2_multiclusterobservability.yaml
oc apply -f ${CURRENT_DIR}/config/metrics-allowlist.yaml

echo "Run \"oc get multiclusterobservability observability -oyaml\" to check the observability status"
