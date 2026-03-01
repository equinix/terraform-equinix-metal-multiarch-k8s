resource "equinix_metal_device" "x86_node" {
  hostname         = format("${var.cluster_name}-x86-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_x86
  plan             = var.plan_x86
  metro            = var.metro != "" ? var.metro : null
  user_data        = templatefile(
    "${path.module}/node.tpl",

    {
      kube_token      = var.kube_token
      primary_node_ip = var.controller_address
      kube_version    = var.kubernetes_version
      ccm_enabled     = var.ccm_enabled
      storage         = var.storage
    }
  )
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-x86"]

  billing_cycle = "hourly"
  project_id    = var.project_id
}

resource "equinix_metal_device" "arm_node" {
  hostname         = format("${var.cluster_name}-arm-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_arm
  plan             = var.plan_arm
  metro            = var.metro
  user_data        = templatefile(
    "${path.module}/node.tpl",

    {
      kube_token      = var.kube_token
      primary_node_ip = var.controller_address
      kube_version    = var.kubernetes_version
      ccm_enabled     = var.ccm_enabled
      storage         = var.storage
    }
  )
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-arm"]

  billing_cycle = "hourly"
  project_id    = var.project_id
}
