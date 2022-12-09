locals {
  ssh_key_name = "metal-key"
}

resource "random_id" "cloud" {
  byte_length = 8
}

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "cluster_private_key_pem" {
  content         = chomp(tls_private_key.ssh_key_pair.private_key_pem)
  filename        = pathexpand(format("%s", local.ssh_key_name))
  file_permission = "0600"
}

resource "local_file" "cluster_public_key" {
  content         = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
  filename        = pathexpand(format("%s.pub", local.ssh_key_name))
  file_permission = "0600"
}

resource "equinix_metal_ssh_key" "kubernetes-on-metal" {
  name       = format("terraform-k8s-%s", random_id.cloud.b64_url)
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "equinix_metal_reserved_ip_block" "kubernetes" {
  project_id = var.metal_create_project ? equinix_metal_project.new_project[0].id : var.project_id
  facility   = var.facility != "" ? var.facility : null
  metro      = var.metro != "" ? var.metro : null
  quantity   = 4
}

module "controllers" {
  source = "./modules/controller_pool"

  kube_token               = module.kube_token_1.token
  kubernetes_version       = var.kubernetes_version
  count_x86                = var.count_x86
  count_gpu                = var.count_gpu
  plan_primary             = var.plan_primary
  facility                 = var.facility
  metro                    = var.metro
  cluster_name             = var.cluster_name
  kubernetes_lb_block      = equinix_metal_reserved_ip_block.kubernetes.cidr_notation
  project_id               = var.metal_create_project ? equinix_metal_project.new_project[0].id : var.project_id
  auth_token               = var.auth_token
  secrets_encryption       = var.secrets_encryption
  configure_ingress        = var.configure_ingress
  storage                  = var.storage
  workloads                = var.workloads
  skip_workloads           = var.skip_workloads
  control_plane_node_count = var.control_plane_node_count
  ssh_private_key_path     = abspath(local_file.cluster_private_key_pem.filename)
  ccm_enabled              = var.ccm_enabled
  loadbalancer_type        = var.loadbalancer_type
  prerequisites            = var.prerequisites

  depends_on = [
    equinix_metal_ssh_key.kubernetes-on-metal # if the primary node is created before the equinix_metal_ssh_key, then the primary node won't be accessible
  ]
}
