terraform {
  required_version = ">= 0.12.2"
}

provider "packet" {
  version    = ">= 2.2.1"
  auth_token = "${var.auth_token}"
}

resource "packet_reserved_ip_block" "kubernetes" {
  project_id = "${var.project_id}"
  facility   = "${var.facility}"
  quantity   = 2
}

module "kube_token_1" {
  source = "./modules/kube-token"
}
