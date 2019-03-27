variable "kube_token" {}
variable "kubernetes_version" {}
variable "pool_label" {}
variable "count_x86" {}
variable "count_arm" {}
variable "plan_x86" {}
variable "plan_arm" {}
variable "facility" {}
variable "cluster_name" {}
variable "controller_address" {}
variable "project_id" {}

data "template_file" "node" {
  template = "${file("${path.module}/node.tpl")}"

  vars {
    kube_token      = "${var.kube_token}"
    primary_node_ip = "${var.controller_address}"
    kube_version    = "${var.kubernetes_version}"
  }
}

resource "packet_device" "x86_node" {
  hostname         = "${format("${var.cluster_name}-x86-${var.pool_label}-%02d", count.index)}"
  operating_system = "ubuntu_18_04"
  count            = "${var.count_x86}"
  plan             = "${var.plan_x86}"
  facility         = "${var.facility}"
  user_data        = "${data.template_file.node.rendered}"

  billing_cycle = "hourly"
  project_id    = "${var.project_id}"
}

resource "packet_device" "arm_node" {
  hostname         = "${format("${var.cluster_name}-arm-${var.pool_label}-%02d", count.index)}"
  operating_system = "ubuntu_18_04"
  count            = "${var.count_arm}"
  plan             = "${var.plan_arm}"
  facility         = "${var.facility}"
  user_data        = "${data.template_file.node.rendered}"

  billing_cycle = "hourly"
  project_id    = "${var.project_id}"
}
