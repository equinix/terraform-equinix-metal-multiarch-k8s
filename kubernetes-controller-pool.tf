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

resource "metal_ssh_key" "kubernetes-on-metal" {
  name       = format("terraform-k8s-%s", random_id.cloud.b64_url)
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "metal_reserved_ip_block" "kubernetes" {
  project_id = var.project_id
  facility   = var.facility
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
  cluster_name             = var.cluster_name
  kubernetes_lb_block      = metal_reserved_ip_block.kubernetes.cidr_notation
  project_id               = var.project_id
  auth_token               = var.auth_token
  secrets_encryption       = var.secrets_encryption
  configure_ingress        = var.configure_ingress
  storage                  = var.storage
  configure_network        = var.configure_network
  workloads                = var.workloads
  skip_workloads           = var.skip_workloads
  network                  = var.network
  control_plane_node_count = var.control_plane_node_count
  ssh_private_key_path     = local_file.cluster_private_key_pem.filename
}
