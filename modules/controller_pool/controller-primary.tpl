#!/bin/bash

function install_docker() {
 echo "Installing Docker..." ; \
 apt-get update; \
 apt-get install -y docker.io && \
 cat << EOF > /etc/docker/daemon.json
 {
   "exec-opts": ["native.cgroupdriver=systemd"]
 }
EOF
}

function enable_docker() {
 systemctl enable docker ; \
 systemctl restart docker
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

function init_cluster_config {
      if [ "${network}" = "calico" ]; then
        export POD_NETWORK="192.168.0.0/16"
      else
        export POD_NETWORK="10.244.0.0/16"
      fi
      cat << EOF > /etc/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
bootstrapTokens:
- token: "${kube_token}"
  description: "default kubeadm bootstrap token"
  ttl: "0"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "$(curl -s http://metadata.packet.net/metadata | jq -r '.network.addresses[] | select(.public == true) | select(.management == true) | select(.address_family == 4) | .address'):6443"
networking:
  podSubnet: $POD_NETWORK
certificatesDir: /etc/kubernetes/pki
EOF
    kubeadm init --config=/etc/kubeadm-config.yaml ; \
    kubeadm init phase upload-certs --upload-certs
}

function init_cluster {
    echo "Initializing cluster..." && \
    if [ "${network}" = "calico" ]; then
      kubeadm init --pod-network-cidr=192.168.0.0/16 --token "${kube_token}" 
    else
      kubeadm init --pod-network-cidr=10.244.0.0/16 --token "${kube_token}"
    fi
    sysctl net.bridge.bridge-nf-call-iptables=1
}

function configure_network {
  if [ "${network}" = "calico" ]; then
      kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml
  else
      kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
  fi
}

function gpu_config {
  if [ "${count_gpu}" = "0" ]; then
	echo "No GPU nodes to prepare for presently...moving on..."
  else
	kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta/nvidia-device-plugin.yml
  fi
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

function ceph_pre_check {
  apt install -y lvm2 ; \
  modprobe rbd
}

function ceph_rook_basic {
  cd /root/kube ; \
  mkdir ceph ; \
  wget https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/common.yaml && \
  wget https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/operator.yaml && \
  if [ "${count}" -gt 3 ]; then
	echo "Node count less than 3, creating minimal cluster" ; \
  	wget https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/cluster-minimal.yaml
  else 
  	wget https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/cluster.yaml
  fi
  echo "Pulled Manifest for Ceph-Rook..." && \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f common.yaml ; \
  sleep 30 ; \
  echo "Applying Ceph Operator..." ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f operator.yaml ; \
  sleep 30 ; \
  echo "Creating Ceph Cluster..." ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f cluster*
}

function ceph_storage_class {
  cat << EOF > /root/kube/ceph-sc.yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  failureDomain: host
  replicated:
    size: 3
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-block
provisioner: ceph.rook.io/block
parameters:
  blockPool: replicapool
  # The value of "clusterNamespace" MUST be the same as the one in which your rook cluster exist
  clusterNamespace: rook-ceph
  fstype: xfs
# Optional, default reclaimPolicy is "Delete". Other options are: "Retain", "Recycle" as documented in https://kubernetes.io/docs/concepts/storage/storage-classes/
reclaimPolicy: Retain
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
	kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/namespace.yaml && \
	kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/metallb.yaml && \
	kubectl --kubeconfig=/etc/kubernetes/admin.conf create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" && \
        kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f metal_lb.yaml
}

install_docker && \
enable_docker && \
install_kube_tools && \
sleep 30 && \
if [ "${control_plane_node_count}" = "0" ]; then
  echo "No control plane nodes provisioned, initializing single master..." ; \
  init_cluster
else
  echo "Writing config for control plane nodes..." ; \
  init_cluster_config
fi
packet_csi_config && \
sleep 180 && \
if [ "${configure_network}" = "no" ]; then
  echo "Not configuring network"
else
  configure_network
fi
if [ "${skip_workloads}" = "yes" ]; then
  echo "Skipping workloads..."
else
  apply_workloads && \
  metal_lb
fi
if [ "${count_gpu}" = "0" ]; then
  echo "Skipping GPU enable..."
else
  gpu_enable
fi
if [ "${storage}" = "openebs" ]; then
   kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://openebs.github.io/charts/openebs-operator-1.2.0.yaml
elif [ "${storage}" = "ceph" ]; then
  ceph_pre_check && \
  echo "Configuring Ceph Operator" ; \
  ceph_rook_basic && \
  ceph_storage_class ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /root/kube/ceph-sc.yaml
else
  echo "Skipping storage provider setup..."
fi
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
