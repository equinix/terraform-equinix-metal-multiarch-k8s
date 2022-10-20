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

  auth_token   = var.auth_token
  project_id   = var.project_id
  metro        = var.metro
  count_arm    = var.count_arm
  count_x86    = var.count_x86
  cluster_name = var.cluster_name
  ccm_enabled  = var.ccm_enabled
}

provider "equinix" {
  auth_token = var.auth_token
}

output "multiarch-k8s" {
  value     = module.multiarch-k8s
  sensitive = true
}
