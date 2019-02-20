provider "packet" {
  version = "1.3.2"
  auth_token = "${var.auth_token}"
}

resource "packet_project" "kubernetes_multiarch" {
  name = "Kubernetes (Multi-Arch)"
}

resource "packet_reserved_ip_block" "kubernetes" {
  project_id = "${packet_project.kubernetes_multiarch.id}"
  facility   = "${var.facility}"
  quantity   = 2
}

resource "random_string" "kube_init_token_a" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "kube_init_token_b" {
  length      = 16
  special     = false
  upper       = false
  min_lower   = 6
  min_numeric = 6
}
