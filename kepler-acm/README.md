# acm-kepler

Enable Kepler in ACM with Observability

## MicroShift

refer to https://github.com/openshift/microshift/blob/main/docs/user/getting_started.md

```sh
sudo subscription-manager register --auto-attach

sudo subscription-manager repos \
    --enable rhocp-4.13-for-rhel-9-$(uname -m)-rpms \
    --enable fast-datapath-for-rhel-9-$(uname -m)-rpms

sudo dnf install -y microshift openshift-clients

sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=169.254.169.1
sudo firewall-cmd --reload

sudo cp .pull-secret.json /etc/crio/openshift-pull-secret

sudo systemctl enable --now microshift.service

mkdir ~/.kube
sudo cat /var/lib/microshift/resources/kubeadmin/kubeconfig > ~/.kube/config

oc get cs
```

## ACM

### Enable the ManifestWorkReplicaSet on the ACM hub

```sh
oc patch clustermanager cluster-manager --type=merge --patch "{\"spec\":{\"workConfiguration\":{\"featureGates\":[{\"feature\":\"ManifestWorkReplicaSet\",\"mode\":\"Enable\"}]}}}"
```

### Create a ManagedClusterSet and add the microshift cluster to this cluster set on the ACM hub

```sh
oc apply -f kepler/clusterset.yaml

oc label managedclusters {cluster name} cluster.open-cluster-management.io/clusterset=microshift --overwrite
```

### Enable Observability on the ACM hub

```sh
./enable-observability.sh
```

### Patch Observability on the MicroShift

```sh
./patch-observability.sh
```

## Kepler

### Create ManifestWorkReplicaSet on the ACM hub to deploy Kepler

```sh
oc apply -k kepler

# check the kepler is deployed on the microshift
oc get manifestworkreplicasets.work.open-cluster-management.io -w
```

### Verify

```sh
# make sure the kepler metrics are collected by observability
oc -n open-cluster-management-addon-observability exec prometheus-k8s-0 -- curl -v "http://127.0.0.1:9090/api/v1/query?query=kepler_container_package_joules_total"

# make sure the kepler metrics are listed in the observability allow list
oc -n open-cluster-management-addon-observability get cm observability-metrics-allowlist -oyaml
```

### Dashboard

1. Following the [ACM doc](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.8/html/observability/using-grafana-dashboards#setting-up-the-grafana-developer-instance) to create a grafana-dev instance
2. Log in to the grafana-dev
3. Import the `dashboard/acm-kepler-exporter.json`

### Metrics

- `kepler_container_bpf_block_irq_total` (counter) Aggregated block irq value obtained from BPF
- `kepler_container_bpf_cpu_time_us_total` (counter) Aggregated CPU time obtained from BPF
- `kepler_container_bpf_net_rx_irq_total` (counter) Aggregated network rx irq value obtained from BPF
- `kepler_container_bpf_net_tx_irq_total` (counter) Aggregated network tx irq value obtained from BPF
- `kepler_container_cgroupfs_cpu_usage_us_total` (counter) Aggregated cpu usage obtained from cGroups
- `kepler_container_cgroupfs_memory_usage_bytes_total` (counter) Aggregated memory bytes obtained from cGroups
- `kepler_container_cgroupfs_system_cpu_usage_us_total` (counter) Aggregated system cpu usage obtained from cGroups
- `kepler_container_cgroupfs_user_cpu_usage_us_total` (counter) Aggregated user cpu usage obtained from cGroups
- `kepler_container_core_joules_total` (counter) Aggregated RAPL value in core in joules
- `kepler_container_dram_joules_total` (counter) Aggregated RAPL value in dram in joules
- `kepler_container_joules_total` (counter) Aggregated RAPL Package + Uncore + DRAM + GPU + other host components (platform - package - dram) in joules
- `kepler_container_kubelet_cpu_usage_total` (counter) Aggregated cpu usage obtained from kubelet
- `kepler_container_kubelet_memory_bytes_total` (counter) Aggregated memory bytes obtained from kubelet
- `kepler_container_other_host_components_joules_total` (counter) Aggregated value in other host components (platform - package - dram) in joules
- `kepler_container_package_joules_total` (counter) Aggregated RAPL value in package (socket) in joules
- `kepler_container_uncore_joules_total` (counter) Aggregated RAPL value in uncore in joules
- `kepler_exporter_build_info` (gauge) A metric with a constant '1' value labeled by version, revision, branch, and goversion from which kepler_exporter was built.
- `kepler_node_core_joules_total` (counter) Aggregated RAPL value in core in joules
- `kepler_node_cpu_scaling_frequency_hertz` (gauge) Current average cpu frequency in hertz
- `kepler_node_dram_joules_total` (counter) Aggregated RAPL value in dram in joules
- `kepler_node_energy_stat` (counter) Several labeled node metrics
- `kepler_node_info` (counter) Labeled node information
- `kepler_node_other_host_components_joules_total` (counter) Aggregated RAPL value in other components (platform - package - dram) in joules
- `kepler_node_package_energy_millijoule` (counter) Aggregated RAPL value in package (socket) in milijoules (deprecated)
- `kepler_node_package_joules_total` (counter) Aggregated RAPL value in package (socket) in joules
- `kepler_node_platform_joules_total` (counter) Aggregated RAPL value in platform (entire node) in joules
- `kepler_node_uncore_joules_total` (counter) Aggregated RAPL value in uncore in joules
- `kepler_pod_energy_stat` (gauge) Several labeled pod metrics
- `kepler_process_bpf_block_irq_total` (counter) Aggregated block irq value obtained from BPF
- `kepler_process_bpf_net_rx_irq_total` (counter) Aggregated network rx irq value obtained from BPF
- `kepler_process_bpf_net_tx_irq_total` (counter) Aggregated network tx irq value obtained from BPF
- `kepler_process_core_joules_total` (counter) Aggregated RAPL value in core in joules
- `kepler_process_cpu_cpu_time_us` (counter) Aggregated CPU time
- `kepler_process_dram_joules_total` (counter) Aggregated RAPL value in dram in joules
- `kepler_process_gpu_joules_total` (counter) Aggregated GPU value in joules
- `kepler_process_joules_total` (counter) Aggregated RAPL Package + Uncore + DRAM + GPU + other host components (platform - package - dram) in joules
- `kepler_process_other_host_components_joules_total` (counter) Aggregated value in other host components (platform - package - dram) in joules
- `kepler_process_package_joules_total` (counter) Aggregated RAPL value in package (socket) in joules
- `kepler_process_uncore_joules_total` (counter) Aggregated RAPL value in uncore in joules
