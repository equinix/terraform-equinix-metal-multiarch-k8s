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

module "multiarch-k8s" {
  source = "../.."
  # source  = "equinix/multiarch-k8s/metal"
  # version = "0.5.0" # Use the latest version, according to https://github.com/equinix/terraform-metal-multiarch-k8s/releases

  # In a production
  auth_token = var.auth_token
  project_id = var.project_id
  metro      = var.metro
}

provider "equinix" {
  auth_token = var.auth_token
}
