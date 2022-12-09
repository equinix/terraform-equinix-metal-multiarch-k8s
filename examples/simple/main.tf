# main.tf
variable "auth_token" {
  type        = string
  description = "Equinix Metal API key"
  sensitive   = true
}

variable "project_id" {
  type        = string
  description = "Equinix Metal Project ID"
}

variable "metro" {
  type        = string
  description = "Equinix Metal Metro"
  default     = "da"
}

variable "count_x86" {
  type        = string
  description = "Number of x86 nodes"
  default     = "3"
}

variable "ccm_enabled" {
  type        = string
  description = "Whether CCM is enabled"
  default     = "true"
}

variable "count_arm" {
  type        = string
  description = "Number of ARM nodes"
  default     = "0"
}

variable "cluster_name" {
  type        = string
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "metal-multiarch-k8s"
}

module "multiarch-k8s" {
  source = "../.."
  # source  = "equinix/multiarch-k8s/metal"
  # version = "0.5.0" # Use the latest version, according to https://github.com/equinix/terraform-metal-multiarch-k8s/releases

  auth_token           = var.auth_token
  project_id           = var.project_id
  metal_create_project = false
  metro                = var.metro
  count_arm            = var.count_arm
  count_x86            = var.count_x86
  cluster_name         = var.cluster_name
  ccm_enabled          = var.ccm_enabled
  prerequisites        = module.cpem.prerequisites
}

provider "equinix" {
  auth_token = var.auth_token
}

output "multiarch-k8s" {
  value     = module.multiarch-k8s
  sensitive = true
}

module "cpem" {
  source = "../../../terraform-equinix-kubernetes-addons/modules/cloud-provider-equinix-metal"
  module_context = {
    k8s_cluster_endpoint = module.multiarch-k8s.kubernetes_api_address
    equinix_metro        = ""
    equinix_project      = ""
    tags                 = {}
  }
  cpem_version = "v3.5.0"
  ssh = {
    user        = "root"
    private_key = chomp(file("../../../terraform-equinix-metal-eks-anywhere/examples/deploy/id_rsa.sos"))
    host        = module.multiarch-k8s.kubernetes_api_address
    # Hack to make the configuration null_resource wait longer without blocking the cloudinit data source from reading
    kubeconfig = length(module.multiarch-k8s.kubernetes_kubeconfig_file) > 0 ? "/etc/kubernetes/admin.conf" : "/etc/kubernetes/admin.conf"
  }
  metal_project_id  = var.project_id
  metal_auth_token  = var.auth_token
  loadbalancer_type = "metallb"
  metro             = var.metro
}