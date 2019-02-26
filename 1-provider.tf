provider "packet" {
  version    = "1.3.2"
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

module "kube_token_1" {
  source = "modules/kube-token"
}
