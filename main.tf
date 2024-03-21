resource "equinix_metal_project" "new_project" {
  count = var.metal_create_project ? 1 : 0
  name  = var.equinix_metal_project_name

  # Kube-vip will enable BGP if not enabled, Terraform must match the settings
  bgp_config {
    deployment_type = "local"
    md5             = ""
    asn             = 65000
  }
}

data "equinix_metal_project" "project" {
  name = var.metal_create_project ? equinix_metal_project.new_project[0].name : var.project_name
}
