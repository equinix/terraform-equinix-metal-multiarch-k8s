locals {
  // Only support MetalLB and Kube-VIP
  loadbalancer_config = var.loadbalancer_type == "metallb" ? "metallb:///${var.metallb_namespace}/${var.metallb_configmap}" : "kube-vip://"
}