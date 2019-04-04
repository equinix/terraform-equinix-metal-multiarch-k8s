#!/bin/bash

function install_docker() {
 echo "Installing Docker..." ; \
 apt-get update; \
 apt-get install -y docker.io && \
 cat << EOF > /etc/docker/daemon.json
 {
   "exec-opts": ["native.cgroupdriver=cgroupfs"]
 }
EOF
}

function install_kube_tools {
 echo "Installing Kubeadm tools..." ; \
 swapoff -a  && \
 apt-get update && apt-get install -y apt-transport-https
 curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
 echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
 apt-get update
 apt-get install -y kubelet=${kube_version} kubeadm=${kube_version} kubectl=${kube_version}
}

function init_cluster {
    echo "Initializing cluster..." && \
    kubeadm init --pod-network-cidr=10.244.0.0/16 --token "${kube_token}" && \
    sysctl net.bridge.bridge-nf-call-iptables=1; \
    # kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl --kubeconfig=/etc/kubernetes/admin.conf version | base64 | tr -d '\n')"
    kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
}

function metal_lb {
    echo "Configuring MetalLB for ${packet_network_cidr}..." && \
    cat << EOF > /root/kube/metal_lb.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: packet-network
      protocol: layer2
      addresses:
      - ${packet_network_cidr}
EOF
}

function packet_csi_config {
  mkdir /root/kube ; \
  cat << EOF > /root/kube/packet-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: packet-cloud-config
  namespace: kube-system
stringData:
  cloud-sa.json: |
    {
    "apiKey": "${packet_auth_token}",
    "projectID": "${packet_project_id}"
    }
EOF
}

function gen_encryption_config {
  echo "Generating EncryptionConfig for cluster..." && \
  export BASE64_STRING=$(head -c 32 /dev/urandom | base64) && \
  cat << EOF > /etc/kubernetes/secrets.conf
apiVersion: v1
kind: EncryptionConfig
resources:
- providers:
  - aescbc:
      keys:
      - name: key1
        secret: $BASE64_STRING
  resources:
  - secrets
EOF
}

function modify_encryption_config {
#Validate Encrypted Secret:
# ETCDCTL_API=3 etcdctl --cert="/etc/kubernetes/pki/etcd/server.crt" --key="/etc/kubernetes/pki/etcd/server.key" --c
acert="/etc/kubernetes/pki/etcd/ca.crt" get /registry/secrets/default/personal-secret | hexdump -C
  echo "Updating Kube APIServer Configuration for At-Rest Secret Encryption..." && \
  sed -i 's|- kube-apiserver|- kube-apiserver\n    - --experimental-encryption-provider-config=/etc/kubernetes/secrets.conf|g' /etc/kubernetes/manifests/kube-apiserver.yaml && \
  sed -i 's|  volumes:|  volumes:\n  - hostPath:\n      path: /etc/kubernetes/secrets.conf\n      type: FileOrCreate\n    name: secretconfig|g' /etc/kubernetes/manifests/kube-apiserver.yaml  && \
  sed -i 's|    volumeMounts:|    volumeMounts:\n    - mountPath: /etc/kubernetes/secrets.conf\n      name: secretconfig\n      readOnly: true|g' /etc/kubernetes/manifests/kube-apiserver.yaml 
}

function apply_workloads {
  echo "Applying workloads..." && \
	cd /root/kube && \
	kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f packet-config.yaml && \
        kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://raw.githubusercontent.com/packethost/csi-packet/master/deploy/kubernetes/setup.yaml && \
        kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://raw.githubusercontent.com/packethost/csi-packet/master/deploy/kubernetes/node.yaml && \
        kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://raw.githubusercontent.com/packethost/csi-packet/master/deploy/kubernetes/controller.yaml && \ 
        kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml && \
        kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f metal_lb.yaml
}

install_docker && \
install_kube_tools && \
sleep 30 && \
init_cluster && \
packet_csi_config && \
metal_lb && \
sleep 180 && \
apply_workloads && \
if [ "${configure_ingress}" = "yes" ]; then
  echo "Configuring Traefik..." ; \
  echo "Making controller schedulable..." ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf taint nodes --all node-role.kubernetes.io/master- && \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-ds.yaml
else
  echo "Skipping ingress..."
fi
if [ "${secrets_encryption}" = "yes" ]; then
  echo "Secrets Encrypted selected...configuring..." && \
  gen_encryption_config && \
  sleep 60 && \
  modify_encryption_config
else
  echo "Secrets Encryption not selected...finishing..."
fi

