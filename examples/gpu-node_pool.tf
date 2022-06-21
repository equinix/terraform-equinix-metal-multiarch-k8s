module "node_pool_gpu_green" {
  source = "equinix/multiarch-k8s/metal//modules/gpu_node_pool"

  kube_token         = module.kube_token_1.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "gpu_green"
  count_gpu          = var.count_gpu
  plan_gpu           = var.plan_gpu
  facility           = var.facility
  metro              = var.metro
  cluster_name       = var.cluster_name
  controller_address = metal_device.k8s_primary.network.0.address
  project_id         = var.project_id
}
