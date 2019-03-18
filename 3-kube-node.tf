module "node_pool_blue" {
  source = "modules/node_pool"

  kube_token         = "${module.kube_token_1.token}"
  kubernetes_version = "${var.kubernetes_version}"
  pool_label         = "blue"
  count_x86          = "${var.count_x86}"
  count_arm          = "${var.count_arm}"
  plan_x86           = "${var.plan_x86}"
  plan_arm           = "${var.plan_arm}"
  facility           = "${var.facility}"
  cluster_name       = "${var.cluster_name}"
  controller_address = "${packet_device.k8s_primary.network.0.address}"
  project_id         = "${var.project_id}"
}

