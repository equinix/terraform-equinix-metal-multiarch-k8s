#!/bin/bash

function install_docker() {
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

install_docker && \
if [ "${ceph}" = "yes" ]; then
  ceph_pre_check
fi ; \
enable_docker && \
install_kube_tools && \
sleep 180
