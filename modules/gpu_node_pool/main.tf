data "cloudinit_config" "gpu_node" {
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
    content = templatefile("${path.module}/gpu_node.tpl", {
      kube_token      = var.kube_token
      primary_node_ip = var.controller_address
      kube_version    = var.kubernetes_version
      storage         = var.storage
      ccm_enabled     = var.ccm_enabled
    })
  }
}

resource "equinix_metal_device" "gpu_node" {
  hostname         = format("${var.cluster_name}-gpu-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_gpu
  plan             = var.plan_gpu
  facilities       = var.facility != "" ? [var.facility] : null
  metro            = var.metro != "" ? var.metro : null
  user_data        = data.cloudinit_config.gpu_node.rendered
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-gpu"]

  billing_cycle = "hourly"
  project_id    = var.project_id
}

