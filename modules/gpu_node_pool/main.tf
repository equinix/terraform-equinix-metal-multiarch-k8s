variable "kube_token" {}
variable "kubernetes_version" {}
variable "pool_label" {}
variable "count_gpu" {}
variable "plan_gpu" {}
variable "facility" {}
variable "cluster_name" {}
variable "controller_address" {}
variable "project_id" {}

data "template_file" "gpu_node" {
  template = "${file("${path.module}/gpu_node.tpl")}"

  vars = {
    kube_token      = "${var.kube_token}"
    primary_node_ip = "${var.controller_address}"
    kube_version    = "${var.kubernetes_version}"
  }
}

resource "packet_device" "gpu_node" {
  hostname         = "${format("${var.cluster_name}-gpu-${var.pool_label}-%02d", count.index)}"
  operating_system = "ubuntu_18_04"
  count            = "${var.count_gpu}"
  plan             = "${var.plan_gpu}"
  facilities       = ["${var.facility}"]
  user_data        = "${data.template_file.gpu_node.rendered}"
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-gpu"]

  billing_cycle = "hourly"
  project_id    = "${var.project_id}"
}

