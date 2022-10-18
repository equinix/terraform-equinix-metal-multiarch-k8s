# main.tf
variable "auth_token" {}
variable "project_id" {} # Or omit to have the module create a project.

module "multiarch-k8s" {
  source  = "equinix/multiarch-k8s/metal"
  version = "0.5.0" # Use the latest version, according to https://github.com/equinix/terraform-metal-multiarch-k8s/releases

  # In a production
  auth_token = var.auth_token
  project_id = var.project_id
}

provider "metal" {
  auth_token = var.auth_token
}
