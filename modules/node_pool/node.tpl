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