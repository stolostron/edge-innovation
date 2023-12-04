#!/bin/bash

####### k8s clients
#######
curl -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
chmod +x oc 
cp oc /var/usrlocal/bin/
chmod +x kubectl 
cp kubectl /var/usrlocal/bin/

mkdir ~/.kube
cp /var/lib/microshift/resources/kubeadmin/kubeconfig ~/.kube/config

####### firewalld
#######
# Mandatory settings
sudo firewall-cmd --permanent --zone=trusted --add-source=10.85.0.0/16 
sudo firewall-cmd --permanent --zone=trusted --add-source=169.254.169.1
sudo firewall-cmd --reload
# Optional settings
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
sudo firewall-cmd --permanent --zone=public --add-port=5353/udp
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/udp
sudo firewall-cmd --permanent --zone=public --add-port=6443/tcp
sudo firewall-cmd --reload

cat <<EOF > /etc/containers/policy.json
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ],
    "transports": {
        "docker": {
            "registry.access.redhat.com": [
                {
                    "type": "signedBy",
                    "keyType": "GPGKeys",
                    "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"
                }
            ],
            "registry.redhat.io": [
                {
                    "type": "signedBy",
                    "keyType": "GPGKeys",
                    "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"
                }
            ]
        },
        "docker-daemon": {
            "": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        }
    }
}
EOF

# copy pull secret
BASEDIR=$(dirname "$0")
cp $BASEDIR/microshift-pull-secret.json /etc/crio/openshift-pull-secret
chmod 600 /etc/crio/openshift-pull-secret

ACM_REGISTRATION_HOST=$(cat $BASEDIR/acm-registration-host)
ACM_REGISTRATION_TOKEN=$(cat $BASEDIR/acm-registration-token)

systemctl restart crio
systemctl restart microshift

sleep 10

# register MicroShift cluster to ACM hub
curl --cacert $BASEDIR/acm-hub-ca.crt -H "Authorization: Bearer $ACM_REGISTRATION_TOKEN" https://$ACM_REGISTRATION_HOST/agent-registration/crds/v1 | oc --kubeconfig /var/lib/microshift/resources/kubeadmin/kubeconfig apply -f -
curl --cacert $BASEDIR/acm-hub-ca.crt -H "Authorization: Bearer $ACM_REGISTRATION_TOKEN" https://$ACM_REGISTRATION_HOST/agent-registration/manifests/microshift-$(tr -dc a-z0-9 </dev/urandom | head -c 5 ; echo '') | oc --kubeconfig /var/lib/microshift/resources/kubeadmin/kubeconfig apply -f -
