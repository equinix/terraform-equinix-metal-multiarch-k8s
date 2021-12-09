#!/bin/bash

export HOME=/root

function install_containerd() {
cat <<EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
 modprobe overlay
 modprobe br_netfilter
 echo "Installing Containerd..."
 apt-get update
 apt-get install -y ca-certificates socat ebtables apt-transport-https cloud-utils prips containerd jq python3
}

function enable_containerd() {
 systemctl daemon-reload
 systemctl enable containerd
 systemctl start containerd
}


function ceph_pre_check {
  apt install -y lvm2 ; \
  modprobe rbd
}

function install_kube_tools() {
 swapoff -a  && \
 apt-get update && apt-get install -y apt-transport-https
 curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
 echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
 apt-get update
 apt-get install -y kubelet=${kube_version} kubeadm=${kube_version} kubectl=${kube_version}
}

install_containerd && \
if [ "${storage}" = "ceph" ]; then
  ceph_pre_check
fi ; \
enable_containerd && \
install_kube_tools && \
sleep 180 ; \
backoff_count=`echo $((5 + RANDOM % 100))` ; \
sleep $backoff_count # Shouldn't there be a kubeadm join command somewhere? Looks like we just install tools and do nothing else
