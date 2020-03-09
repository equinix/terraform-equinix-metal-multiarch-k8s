variable "kube_token" {}
variable "kubernetes_version" {}
variable "facility" {}
variable "cluster_name" {}
variable "project_id" {}
variable "auth_token" {}
variable "secrets_encryption" {}
variable "storage" {}
variable "configure_network" {}
variable "configure_ingress" {}
variable "skip_workloads" {}
variable "network" {}
variable "plan_primary" {}
variable "count_x86" {}
variable "count_gpu" {}
variable "kubernetes_lb_block" {}
variable "control_plane_node_count" {}
variable "ssh_private_key_path" {}

data "template_file" "controller-primary" {
  template = file("${path.module}/controller-primary.tpl")

  vars = {
    kube_token               = var.kube_token
    packet_network_cidr      = var.kubernetes_lb_block
    packet_auth_token        = var.auth_token
    packet_project_id        = var.project_id
    kube_version             = var.kubernetes_version
    secrets_encryption       = var.secrets_encryption
    configure_ingress        = var.configure_ingress
    count                    = var.count_x86
    count_gpu                = var.count_gpu
    storage                  = var.storage
    configure_network        = var.configure_network
    skip_workloads           = var.skip_workloads
    network                  = var.network
    control_plane_node_count = var.control_plane_node_count
  }
}

resource "packet_device" "k8s_primary" {
  hostname         = "${var.cluster_name}-controller-primary"
  operating_system = "ubuntu_18_04"
  plan             = var.plan_primary
  facilities       = [var.facility]
  user_data        = data.template_file.controller-primary.rendered
  tags             = ["kubernetes", "controller-${var.cluster_name}"]

  billing_cycle = "hourly"
  project_id    = var.project_id
}

data "template_file" "controller-standby" {
  template = file("${path.module}/controller-standby.tpl")

  vars = {
    kube_token      = var.kube_token
    primary_node_ip = packet_device.k8s_primary.network.0.address
    kube_version    = var.kubernetes_version
    storage         = var.storage
  }
}

resource "packet_device" "k8s_controller_standby" {

  depends_on = [packet_device.k8s_primary]

  hostname         = format("${var.cluster_name}-controller-standby-%02d", count.index)
  operating_system = "ubuntu_18_04"
  plan             = var.plan_primary
  facilities       = [var.facility]
  user_data        = data.template_file.controller-standby.rendered
  tags             = ["kubernetes", "controller-${var.cluster_name}"]

  count = var.control_plane_node_count

  provisioner "local-exec" {
    environment = {
      controller           = packet_device.k8s_primary.network.0.address
      node_addr            = self.access_public_ipv4
      kube_token           = var.kube_token
      ssh_private_key_path = var.ssh_private_key_path
    }
    command = "sh scripts/key_wait_transfer.sh"
  }

  billing_cycle = "hourly"
  project_id    = var.project_id
}

resource "packet_ip_attachment" "kubernetes_lb_block" {
  device_id     = packet_device.k8s_primary.id
  cidr_notation = var.kubernetes_lb_block
}
