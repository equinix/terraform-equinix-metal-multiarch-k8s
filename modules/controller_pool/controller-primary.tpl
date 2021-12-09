#!/usr/bin/env bash

export HOME=/root
export WORKLOADS=$(echo ${workloads})
mkdir $HOME/kube

function load_workloads() {
  echo "{"| tee -a $HOME/workloads.json ; for w in $WORKLOADS; do \ 
  echo $w | sed 's| |\n|'g | awk '{sub(/:/,"\":\"")}1' | sed 's/.*/"&",/' | tee -a $HOME/workloads.json; \
  done ; echo "\"applied_at\":\"$(date +%F:%H:%m:%S)\"" | tee -a $HOME/workloads.json \
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
      export CNI_CIDR="$(cat $HOME/workloads.json | jq .cni_cidr)" && \
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
  podSubnet: $CNI_CIDR
certificatesDir: /etc/kubernetes/pki
EOF
    kubeadm init --config=/etc/kubeadm-config.yaml ; \
    kubeadm init phase upload-certs --upload-certs
}

function init_cluster {
    export CNI_CIDR=$(cat $HOME/workloads.json | jq .cni_cidr) && \
    echo "Initializing cluster..." && \
    kubeadm init --pod-network-cidr=$(cat $HOME/workloads.json | jq .cni_cidr | sed "s/^\([\"']\)\(.*\)\1\$/\2/g") --token "${kube_token}" 
    sysctl net.bridge.bridge-nf-call-iptables=1
}

function configure_network {
  workload_manifests=$(cat $HOME/workloads.json | jq .cni_workloads | sed "s/^\([\"']\)\(.*\)\1\$/\2/g" | tr , '\n') && \
  for w in $workload_manifests; do 
    kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $w
  done
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
  namespace: ${metallb_namespace}
  name: ${metallb_configmap}
data:
  config: |
    address-pools:
    - name: metal-network
      protocol: layer2
      addresses:
      - ${metal_network_cidr}
EOF

  echo "Applying MetalLB manifests..." && \
    cd $HOME/kube && \
    kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .metallb_namespace) && \
    kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .metallb_release) && \
    kubectl --kubeconfig=/etc/kubernetes/admin.conf create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" && \
    kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f metal_lb.yaml
}

function kube_vip {
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://kube-vip.io/manifests/rbac.yaml
  docker run --network host --rm ghcr.io/kube-vip/kube-vip:v0.4.0 manifest daemonset \
  --interface lo \
  --services \
  --bgp \
  --annotations metal.equinix.com \
  --inCluster | kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f -
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

function apply_extra {
  workload_manifests=$(cat $HOME/workloads.json | jq .extra | sed "s/^\([\"']\)\(.*\)\1\$/\2/g" | tr , '\n') && \
  if [ "$workload_manifests" == "" ]; then
    echo "Done."
  else
    for w in $workload_manifests; do 
      kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $w
    done
  fi
}

function install_ccm {
  cat << EOF > $HOME/kube/equinix-ccm-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: metal-cloud-config
  namespace: kube-system
stringData:
  cloud-sa.json: |
    {
      "apiKey": "${equinix_api_key}",
      "projectID": "${equinix_project_id}",
      "loadbalancer": "${loadbalancer}"
    }
EOF

kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $HOME/kube/equinix-ccm-config.yaml
RELEASE=${ccm_version}
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/equinix/cloud-provider-equinix-metal/releases/download/$RELEASE/deployment.yaml
}

install_docker && \
enable_docker && \
load_workloads && \
install_kube_tools && \
sleep 30 && \
if [ "${ccm_enabled}" = "true" ]; then
  echo KUBELET_EXTRA_ARGS=\"--cloud-provider=external\" > /etc/default/kubelet
fi
if [ "${control_plane_node_count}" = "0" ]; then
  echo "No control plane nodes provisioned, initializing single master..." ; \
  init_cluster
else
  echo "Writing config for control plane nodes..." ; \
  init_cluster_config
fi

sleep 180 && \
configure_network
if [ "${ccm_enabled}" = "true" ]; then
install_ccm
sleep 30 # The CCM will probably take a while to reconcile
fi
if [ "${loadbalancer_type}" = "metallb" ]; then
metal_lb
fi
if [ "${loadbalancer_type}" = "kube-vip" ]; then
kube_vip
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
  echo "Making controller schedulable..." ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf taint nodes --all node-role.kubernetes.io/master- && \
  echo "Configuring Ingress Controller..." ; \
  kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f $(cat $HOME/workloads.json | jq .ingress_controller )
else
  echo "Not configuring ingress controller..."
fi
if [ "${secrets_encryption}" = "yes" ]; then
  echo "Secrets Encrypted selected...configuring..." && \
  gen_encryption_config && \
  sleep 60 && \
  modify_encryption_config
else
  echo "Secrets Encryption not selected...finishing..."
fi
apply_extra || echo "Extra workloads not applied. Finished."
