#!/bin/bash

export HOME=/root

function nvidia_configure() {
 distribution=$(. /etc/os-release;echo $ID$VERSION_ID) ; \
 curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - ; \
 curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list ; \
 sudo apt-get update && sudo apt-get install -y nvidia-container-runtime nvidia-cuda-toolkit
}

function nvidia_drivers() {
  sudo sed -i 's/^#root/root/' /etc/nvidia-container-runtime/config.toml && \
  sudo tee /etc/modules-load.d/ipmi.conf <<< "ipmi_msghandler" \
  && sudo tee /etc/modprobe.d/blacklist-nouveau.conf <<< "blacklist nouveau" \
  && sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf <<< "options nouveau modeset=0" && \
  sudo update-initramfs -u
  sudo ctr i pull docker.io/nvidia/driver:450.80.02-ubuntu18.04
  sudo ctr run --rm --privileged --with-ns pid:/proc/1/ns/pid --net-host --detach \
  --mount type=bind,src=/run/nvidia,dest=/run/nvidia,options=shared \
  --mount type=bind,src=/var/log,dest=/var/log \
  docker.io/nvidia/driver:450.80.02-ubuntu18.04 nvidia-driver-$RANDOM
}

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
 echo "Waiting 180s to attempt to join cluster..."
}

function join_cluster() {
	echo "Attempting to join cluster" && \
    kubeadm join "${primary_node_ip}:6443" --token "${kube_token}" --discovery-token-unsafe-skip-ca-verification
}

install_containerd && \
nvidia_configure && \
nvidia_drivers && \
enable_containerd && \
if [ "${storage}" = "ceph" ]; then
  ceph_pre_check
fi ; \
install_kube_tools && \
sleep 180 && \
if [ "${ccm_enabled}" = "true" ]; then
  echo KUBELET_EXTRA_ARGS=\"--cloud-provider=external\" > /etc/default/kubelet
fi
join_cluster
