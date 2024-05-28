data "template_file" "controller-primary" {
  template = file("${path.module}/controller-primary.tpl")

  vars = {
    kube_token               = var.kube_token
    metal_network_cidr       = var.kubernetes_lb_block
    metal_auth_token         = var.auth_token
    equinix_metal_project_id = var.project_id
    kube_version             = var.kubernetes_version
    secrets_encryption       = var.secrets_encryption ? "yes" : "no"
    configure_ingress        = var.configure_ingress ? "yes" : "no"
    count                    = var.count_x86
    count_gpu                = var.count_gpu
    storage                  = var.storage
    skip_workloads           = var.skip_workloads ? "yes" : "no"
    workloads                = jsonencode(var.workloads)
    control_plane_node_count = var.control_plane_node_count
    equinix_api_key          = var.auth_token
    equinix_project_id       = var.project_id
    loadbalancer             = local.loadbalancer_config
    loadbalancer_type        = var.loadbalancer_type
    ccm_version              = var.ccm_version
    ccm_enabled              = var.ccm_enabled
    metallb_namespace        = var.metallb_namespace
    metallb_configmap        = var.metallb_configmap
    equinix_metro            = var.metro
  }
}

resource "equinix_metal_device" "k8s_primary" {
  hostname         = "${var.cluster_name}-controller-primary"
  operating_system = "ubuntu_22_04"
  plan             = var.plan_primary
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.template_file.controller-primary.rendered
  tags             = ["kubernetes", "controller-${var.cluster_name}"]

  billing_cycle = "hourly"
  project_id    = var.project_id
}

data "template_file" "controller-standby" {
  template = file("${path.module}/controller-standby.tpl")

  vars = {
    kube_token      = var.kube_token
    primary_node_ip = equinix_metal_device.k8s_primary.network.0.address
    kube_version    = var.kubernetes_version
    storage         = var.storage
  }
}

resource "equinix_metal_device" "k8s_controller_standby" {
  count      = var.control_plane_node_count
  depends_on = [equinix_metal_device.k8s_primary]

  hostname         = format("${var.cluster_name}-controller-standby-%02d", count.index)
  operating_system = "ubuntu_22_04"
  plan             = var.plan_primary
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.template_file.controller-standby.rendered
  tags             = ["kubernetes", "controller-${var.cluster_name}"]
  billing_cycle    = "hourly"
  project_id       = var.project_id
}

resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    environment = {
      controller           = equinix_metal_device.k8s_primary.network.0.address
      kube_token           = var.kube_token
      ssh_private_key_path = var.ssh_private_key_path
      local_path           = path.root
    }

    command = "sh ${path.module}/assets/kubeconfig_copy.sh"
  }

  depends_on = [
    null_resource.key_wait_transfer
  ]
}

data "local_file" "kubeconfig" {
  filename = abspath("${path.root}/kubeconfig")

  depends_on = [
    null_resource.kubeconfig
  ]
}

resource "null_resource" "key_wait_transfer" {
  count = var.control_plane_node_count

  connection {
    type        = "ssh"
    user        = "root"
    host        = equinix_metal_device.k8s_controller_standby[count.index].access_public_ipv4
    private_key = file(var.ssh_private_key_path)
    password    = equinix_metal_device.k8s_controller_standby[count.index].root_password
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait"]
  }

  provisioner "local-exec" {
    environment = {
      controller           = equinix_metal_device.k8s_primary.network.0.address
      node_addr            = equinix_metal_device.k8s_controller_standby[count.index].access_public_ipv4
      kube_token           = var.kube_token
      ssh_private_key_path = var.ssh_private_key_path
    }

    command = "sh ${path.module}/assets/key_wait_transfer.sh"
  }
}

resource "equinix_metal_ip_attachment" "kubernetes_lb_block" {
  device_id     = equinix_metal_device.k8s_primary.id
  cidr_notation = var.kubernetes_lb_block
}
