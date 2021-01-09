module "node_pool_blue" {
  source = "./modules/node_pool"

  kube_token         = module.kube_token_1.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "blue"
  count_x86          = var.count_x86
  count_arm          = var.count_arm
  plan_x86           = var.plan_x86
  plan_arm           = var.plan_arm
  facility           = var.facility
  cluster_name       = var.cluster_name
  controller_address = module.controllers.controller_addresses
  project_id         = var.project_id
  storage            = var.storage
}

module "node_pool_gpu_green" {
  source = "./modules/gpu_node_pool"

  kube_token         = module.kube_token_1.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "gpu_green"
  count_gpu          = var.count_gpu
  plan_gpu           = var.plan_gpu
  facility           = var.facility
  cluster_name       = var.cluster_name
  controller_address = module.controllers.controller_addresses
  project_id         = var.project_id
  storage            = var.storage
}
