variable "kube_token" {}
variable "kubernetes_version" {}
variable "facility" {}
variable "cluster_name" {}
variable "project_id" {}
variable "auth_token" {}
variable "secrets_encryption" {}
variable "ceph" {}
variable "configure_network" {}
variable "configure_ingress" {}
variable "skip_workloads" {}
variable "network" {}
variable "plan_primary" {}
variable "count_x86" {}
variable "count_gpu" {}
variable "kubernetes_lb_block" {}

data "template_file" "controller" {
  template = "${file("${path.module}/controller.tpl")}"

  vars = {
    kube_token          = "${var.kube_token}"
    packet_network_cidr = "${var.kubernetes_lb_block}"
    packet_auth_token   = "${var.auth_token}"
    packet_project_id   = "${var.project_id}"
    kube_version        = "${var.kubernetes_version}"
    secrets_encryption  = "${var.secrets_encryption}"
    configure_ingress   = "${var.configure_ingress}"
    count               = "${var.count_x86}"
    count_gpu           = "${var.count_gpu}"
    ceph                = "${var.ceph}"
    configure_network   = "${var.configure_network}"
    skip_workloads      = "${var.skip_workloads}"
    network             = "${var.network}"
  }
}

resource "packet_device" "k8s_primary" {
  hostname         = "${var.cluster_name}-controller"
  operating_system = "ubuntu_18_04"
  plan             = "${var.plan_primary}"
  facilities       = ["${var.facility}"]
  user_data        = "${data.template_file.controller.rendered}"
  tags             = ["kubernetes", "controller-${var.cluster_name}"]

  billing_cycle = "hourly"
  project_id    = "${var.project_id}"
}

resource "packet_ip_attachment" "kubernetes_lb_block" {
  device_id     = "${packet_device.k8s_primary.id}"
  cidr_notation = "${var.kubernetes_lb_block}"
}
