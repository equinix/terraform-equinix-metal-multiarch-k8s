resource "metal_project" "new_project" {
  count = var.metal_create_project ? 1 : 0
  name  = var.metal_project_name
}

provider "metal" {
  auth_token = var.auth_token
}
