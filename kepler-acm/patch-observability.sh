#!/bin/bash

cat << EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: endpoint-observability-operator-clusterrole
rules:
- apiGroups:
  - observability.open-cluster-management.io
  resources:
  - observabilityaddons/finalizers
  verbs:
  - get
  - update
- apiGroups:
  - ""
  resources:
  - services
  - endpoints
  - pods
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: endpoint-observability-operator-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: endpoint-observability-operator-clusterrole
subjects:
- kind: ServiceAccount
  name: endpoint-observability-operator-sa
  namespace: open-cluster-management-addon-observability
EOF


oc label ns open-cluster-management-addon-observability pod-security.kubernetes.io/enforce=privileged --overwrite
oc label ns open-cluster-management-addon-observability pod-security.kubernetes.io/audit=privileged --overwrite
oc label ns open-cluster-management-addon-observability pod-security.kubernetes.io/warn=privileged --overwrite
oc label ns open-cluster-management-addon-observability security.openshift.io/scc.podSecurityLabelSync=false --overwrite

oc adm policy add-scc-to-user privileged -z node-exporter -n open-cluster-management-addon-observability
oc adm policy add-scc-to-user privileged -z kube-state-metrics -n open-cluster-management-addon-observability
oc create namespace kepler
oc adm policy add-scc-to-user privileged -z kepler -n kepler

oc -n open-cluster-management-addon-observability delete pods --all --force --grace-period=0

echo "Waiting the pods restart ..."
sleep 30

oc -n open-cluster-management-addon-observability patch daemonset/node-exporter --patch \
    "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"last-restart\":\"`date +'%s'`\"}}}}}"

oc -n open-cluster-management-addon-observability patch deployment/kube-state-metrics --patch \
    "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"last-restart\":\"`date +'%s'`\"}}}}}"


echo "Run \"oc -n open-cluster-management-addon-observability get pods\" to check the observability agent status"
