module "node_pool_green" {
  source = "equinix/multiarch-k8s/metal/modules/node_pool"

  # Or if the modules are copied locally:
  # source = "./modules/node_pool"

  kube_token         = module.kube_token_2.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "green"
  count_x86          = var.count_x86
  count_arm          = var.count_arm
  plan_x86           = var.plan_x86
  plan_arm           = var.plan_arm
  facility           = var.facility
  metro              = var.metro
  cluster_name       = var.cluster_name
  controller_address = metal_device.k8s_primary.network.0.address
  project_id         = metal_project.kubernetes_multiarch.id
}

module "kube_token_2" {
  source = "modules/kube-token"
}
