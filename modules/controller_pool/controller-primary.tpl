#!/usr/bin/env bash

export HOME=/root
export WORKLOADS=$(echo ${workloads})
mkdir $HOME/kube

function load_workloads() {
  echo "{"| tee -a $HOME/workloads.json ; for w in $WORKLOADS; do \ 
  echo $w | sed 's| |\n|'g | awk '{sub(/:/,"\":\"")}1' | sed 's/.*/"&",/' | tee -a $HOME/workloads.json; \
  done ; echo "\"additional\":\"\"" | tee -a $HOME/workloads.json \
  ; echo "}" | tee -a $HOME/workloads.json
}

function install_docker() {
 echo "Installing Docker..." ; \
 apt-get update; \
 apt-get install -y docker.io jq python3 && \
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
controlPlaneEndpoint: "$(curl -s http://metadata.platformequinix.com/metadata | jq -r '.network.addresses[] | select(.public == true) | select(.management == true) | select(.address_family == 4) | .address'):6443"
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
      kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f $(cat $HOME/workloads.json | jq .tigera_operator)
      kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f $(cat $HOME/workloads.json | jq .calico)
  else
      kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .flannel)
  fi
}

function gpu_config {
  if [ "${count_gpu}" = "0" ]; then
	echo "No GPU nodes to prepare for presently...moving on..."
  else
	kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f $(cat $HOME/workloads.json | jq .nvidia_gpu)
  fi
}

function metal_lb {
    echo "Configuring MetalLB for ${metal_network_cidr}..." && \
    cd $HOME/kube ; \
    cat << EOF > metal_lb.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: metal-network
      protocol: layer2
      addresses:
      - ${metal_network_cidr}
EOF
}

function ceph_pre_check {
  apt install -y lvm2 ; \
  modprobe rbd
}

function ceph_rook_basic {
  cd $HOME/kube ; \
  mkdir ceph ;\ 
  echo "Pulled Manifest for Ceph-Rook..." && \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f $(cat $HOME/workloads.json | jq .ceph_common) ; \
  sleep 30 ; \
  echo "Applying Ceph Operator..." ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f $(cat $HOME/workloads.json | jq .ceph_operator) ; \
  sleep 30 ; \
  echo "Creating Ceph Cluster..." ; \
  if [ "${count}" -gt 3 ]; then
	  echo "Node count less than 3, creating minimal cluster" ; \
  	kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f $(cat $HOME/workloads.json | jq .ceph_cluster_minimal)
  else 
  	kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f $(cat $HOME/workloads.json | jq .ceph_cluster)
  fi
}

function ceph_storage_class {
  cat << EOF > $HOME/kube/ceph-sc.yaml
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
	cd $HOME/kube && \
	kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .metallb_namespace) && \
	kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .metallb_release) && \
	kubectl --kubeconfig=/etc/kubernetes/admin.conf create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" && \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f metal_lb.yaml
}

install_docker && \
enable_docker && \
load_workloads && \
install_kube_tools && \
sleep 30 && \
if [ "${control_plane_node_count}" = "0" ]; then
  echo "No control plane nodes provisioned, initializing single master..." ; \
  init_cluster
else
  echo "Writing config for control plane nodes..." ; \
  init_cluster_config
fi

sleep 180 && \
if [ "${configure_network}" = "no" ]; then
  echo "Not configuring network"
else
  configure_network
fi
if [ "${skip_workloads}" = "yes" ]; then
  echo "Skipping workloads..."
else
  metal_lb && \
  apply_workloads
fi
if [ "${count_gpu}" = "0" ]; then
  echo "Skipping GPU enable..."
else
  gpu_enable
fi
if [ "${storage}" = "openebs" ]; then
   kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .open_ebs_operator)
elif [ "${storage}" = "ceph" ]; then
  ceph_pre_check && \
  echo "Configuring Ceph Operator" ; \
  ceph_rook_basic && \
  ceph_storage_class ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $HOME/kube/ceph-sc.yaml
else
  echo "Skipping storage provider setup..."
fi
if [ "${configure_ingress}" = "yes" ]; then
  echo "Configuring Traefik..." ; \
  echo "Making controller schedulable..." ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf taint nodes --all node-role.kubernetes.io/master- && \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .traefik )
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
