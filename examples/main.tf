# main.tf
provider "metal" {
  auth_token = var.auth_token
}

module "multiarch-k8s" {
  source  = "equinix/multiarch-k8s/metal"
  version = "0.1.0" # Use the latest version, according to https://github.com/equinix/terraform-metal-multiarch-k8s/releases

  # In a production
  auth_token = var.auth_token
  project_id = var.project_id
}

