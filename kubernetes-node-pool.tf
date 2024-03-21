module "node_pool_blue" {
  source = "./modules/node_pool"

  kube_token         = module.kube_token_1.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "blue"
  count_x86          = var.count_x86
  count_arm          = var.count_arm
  plan_x86           = var.plan_x86
  plan_arm           = var.plan_arm
  metro              = var.metro
  cluster_name       = var.cluster_name
  controller_address = module.controllers.controller_addresses
  project_id         = var.metal_create_project ? equinix_metal_project.new_project[0].id : data.equinix_metal_project.project.project_id
  storage            = var.storage
  ccm_enabled        = var.ccm_enabled

}

module "node_pool_gpu_green" {
  source = "./modules/gpu_node_pool"

  kube_token         = module.kube_token_1.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "gpu-green"
  count_gpu          = var.count_gpu
  plan_gpu           = var.plan_gpu
  metro              = var.metro
  cluster_name       = var.cluster_name
  controller_address = module.controllers.controller_addresses
  project_id         = var.metal_create_project ? equinix_metal_project.new_project[0].id : data.equinix_metal_project.project.project_id
  storage            = var.storage
  ccm_enabled        = var.ccm_enabled
}
