resource "metal_project" "new_project" {
  count = var.metal_create_project ? 1 : 0
  name  = var.metal_project_name

  # Kube-vip will enable BGP if not enabled, Terraform must match the settings
  bgp_config {
    deployment_type = "local"
    md5             = ""
    asn             = 65000
  }
}
