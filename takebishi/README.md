# acm-takebishi

Inspired by [multicloud-gitops-with-takebishi](https://github.com/yd-ono/multicloud-gitops-with-takebishi), we use ACM
`ManagedClusterAddOn` to deploy the Takebishi device gateway and AMQ broker in MicroShifts.

The ACM `ManagedClusterAddOn` can help user

- Deploy applications easily
- Update applications easily
- Configure applications easily
- Schedule applications among manage clusters easily 

## Preparation

1. Run `oc apply -k deploy/acm/hub` in your ACM hub cluster to prepare:
    - A managed cluster set `edge-clusters`, it groups your MicroShift clusters
    - A cluster management add-on `amq-broker`, it defines the AMQ broker add-on
    - A cluster management add-on `takebishi-device-gateway`, it defines the Takebishi device gateway add-on
    - A `takebishi-dgw-demo` namespace
    - A `ManagedClusterSetBinding` in the `takebishi-dgw-demo` namespace, it binds the `edge-clusters` cluster set
    - A `Placement` in the `takebishi-dgw-demo` namespace, it selects the MicroShift clusters from the `edge-clusters` cluster set
    - A `AddOnDeploymentConfig` in the `takebishi-dgw-demo` namespace, it holds the configuration of the Takebishi device gateway and AMQ broker
2. Prepare a MicroShift cluster
    ```sh
    # refer to https://github.com/openshift/microshift/blob/main/docs/user/getting_started.md

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
3. Import your MicroShift cluster to the ACM hub cluster and add it to the `edge-clusters` cluster set
4. Run `oc -n <your-microshift-cluster-name> apply -f deploy/acm/microshift/permission.yaml` to escalate the work agent permission in your
MicroShift cluster to allow the work agent operating the `route.openshift.io`
5. If your MicroShift cluster did not enable the LVM CSI plugin, run `oc -n <your-microshift-cluster-name> apply -f deploy/acm/microshift/localstorage.yaml` to prepare the local pv in your MicroShift cluster.

## Deploy

Run the following commands on your ACM hub to deploy the AMQ broker and Takebishi device gateway

```shell
clusteradm addon create amq-broker --version='7.8.0' -f deploy/amq-broker/manifests
clusteradm addon create takebishi-device-gateway --version='3.3.0' -f deploy/takebishi/manifests
```

Then you can check the AMQ broker and Takebishi device gateway status by the managed cluster addon, e.g.

```shell
oc -n <your-microshift-cluster-name> get managedclusteraddon
```

```
NAME                       AVAILABLE   DEGRADED   PROGRESSING
amq-broker                 True                   True
takebishi-device-gateway   True                   True
work-manager               True
```

After AMQ broker and Takebishi device gateway become available, access the Takebishi device gateway by its route host `dgw-takebishi.<your-microshift-route-domain>` (By default, the route domain will be `apps.example.com`)
