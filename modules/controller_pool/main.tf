data "cloudinit_config" "k8s_primary" {
  gzip          = false
  base64_encode = false

  dynamic "part" {
    for_each = var.prerequisites
    content {
      content_type = part.value.content_type
      content      = part.value.content
      filename     = part.value.filename
      merge_type   = part.value.merge_type
    }
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/controller-primary.tpl", {
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
      ccm_enabled              = var.ccm_enabled
      ccm_version              = var.ccm_version
      metallb_namespace        = var.metallb_namespace
      metallb_configmap        = var.metallb_configmap
      equinix_metro            = var.metro
      equinix_facility         = var.facility
    })
  }
}

resource "equinix_metal_device" "k8s_primary" {
  hostname         = "${var.cluster_name}-controller-primary"
  operating_system = "ubuntu_18_04"
  plan             = var.plan_primary
  facilities       = var.facility != "" ? [var.facility] : null
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.cloudinit_config.k8s_primary.rendered
  tags             = ["kubernetes", "controller-${var.cluster_name}"]

  billing_cycle = "hourly"
  project_id    = var.project_id
}

data "cloudinit_config" "k8s_controller_secondary" {
  gzip          = false
  base64_encode = false

  dynamic "part" {
    for_each = var.prerequisites
    content {
      content_type = part.value.content_type
      content      = part.value.content
      filename     = part.value.filename
      merge_type   = part.value.merge_type
    }
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/controller-standby.tpl", {
      kube_token      = var.kube_token
      primary_node_ip = equinix_metal_device.k8s_primary.network.0.address
      kube_version    = var.kubernetes_version
      storage         = var.storage
    })
  }
}

resource "equinix_metal_device" "k8s_controller_standby" {
  count      = var.control_plane_node_count
  depends_on = [equinix_metal_device.k8s_primary]

  hostname         = format("${var.cluster_name}-controller-standby-%02d", count.index)
  operating_system = "ubuntu_18_04"
  plan             = var.plan_primary
  facilities       = var.facility != "" ? [var.facility] : null
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.cloudinit_config.k8s_controller_secondary.rendered
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
