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
  apt-get update && apt-get install -y gnupg2 software-properties-common apt-transport-https ca-certificates socat ebtables cloud-utils prips jq python3
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update && apt-get install -y containerd.io
  # Configure containerd
  mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
  sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
}

function enable_containerd() {
  systemctl daemon-reload
  systemctl restart containerd
  systemctl enable containerd
}

function ceph_pre_check {
  apt install -y lvm2 ; \
  modprobe rbd
}

function bgp_routes {
  GATEWAY_IP=$(curl https://metadata.platformequinix.com/metadata | jq -r ".network.addresses[] | select(.public == false) | .gateway")
  # TODO use metadata peer ips
  ip route add 169.254.255.1 via $GATEWAY_IP
  ip route add 169.254.255.2 via $GATEWAY_IP
  sed -i.bak -E "/^\s+post-down route del -net 10\.0\.0\.0.* gw .*$/a \ \ \ \ up ip route add 169.254.255.1 via $GATEWAY_IP || true\n    up ip route add 169.254.255.2 via $GATEWAY_IP || true\n    down ip route del 169.254.255.1 || true\n    down ip route del 169.254.255.2 || true" /etc/network/interfaces
}

function install_kube_tools() {
  sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
  swapoff -a
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
  apt-get update
  apt-get install -y kubelet=${kube_version} kubeadm=${kube_version} kubectl=${kube_version}
  echo "Waiting 180s to attempt to join cluster..."
}

function join_cluster() {
	echo "Attempting to join cluster"
  tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

  sysctl --system
  kubeadm join "${primary_node_ip}:6443" --token "${kube_token}" --discovery-token-unsafe-skip-ca-verification
}

install_containerd && \
nvidia_configure && \
nvidia_drivers && \
enable_containerd && \
if [ "${storage}" = "ceph" ]; then
  ceph_pre_check
fi ; \
bgp_routes && \
install_kube_tools && \
sleep 180 && \
if [ "${ccm_enabled}" = "true" ]; then
  echo KUBELET_EXTRA_ARGS=\"--cloud-provider=external\" > /etc/default/kubelet
fi
join_cluster
