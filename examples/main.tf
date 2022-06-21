# main.tf
provider "metal" {
  auth_token = var.auth_token
}

module "multiarch-k8s" {
  source  = "equinix/multiarch-k8s/metal"
  # version omitted for CI testing.
  # Use the latest according to https://github.com/equinix/terraform-metal-multiarch-k8s/releases
  # version = "0.1.0"

  # In a production
  auth_token = var.auth_token
  project_id = var.project_id
}

