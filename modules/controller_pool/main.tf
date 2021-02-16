data "template_file" "controller-primary" {
  template = file("${path.module}/controller-primary.tpl")

  vars = {
    kube_token               = var.kube_token
    metal_network_cidr       = var.kubernetes_lb_block
    metal_auth_token         = var.auth_token
    metal_project_id         = var.project_id
    kube_version             = var.kubernetes_version
    secrets_encryption       = var.secrets_encryption ? "yes" : "no"
    configure_ingress        = var.configure_ingress ? "yes" : "no"
    count                    = var.count_x86
    count_gpu                = var.count_gpu
    storage                  = var.storage
    configure_network        = var.configure_network ? "yes" : "no"
    skip_workloads           = var.skip_workloads ? "yes" : "no"
    network                  = var.network
    control_plane_node_count = var.control_plane_node_count
  }
}

resource "metal_device" "k8s_primary" {
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
    primary_node_ip = metal_device.k8s_primary.network.0.address
    kube_version    = var.kubernetes_version
    storage         = var.storage
  }
}

resource "metal_device" "k8s_controller_standby" {

  depends_on = [metal_device.k8s_primary]

  hostname         = format("${var.cluster_name}-controller-standby-%02d", count.index)
  operating_system = "ubuntu_18_04"
  plan             = var.plan_primary
  facilities       = [var.facility]
  user_data        = data.template_file.controller-standby.rendered
  tags             = ["kubernetes", "controller-${var.cluster_name}"]

  count = var.control_plane_node_count

  provisioner "local-exec" {
    environment = {
      controller           = metal_device.k8s_primary.network.0.address
      node_addr            = self.access_public_ipv4
      kube_token           = var.kube_token
      ssh_private_key_path = var.ssh_private_key_path
    }
    command = "sh scripts/key_wait_transfer.sh"
  }

  billing_cycle = "hourly"
  project_id    = var.project_id
}

resource "metal_ip_attachment" "kubernetes_lb_block" {
  device_id     = metal_device.k8s_primary.id
  cidr_notation = var.kubernetes_lb_block
}
