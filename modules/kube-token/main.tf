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

output "token" {
  value = "${random_string.kube_init_token_a.result}.${random_string.kube_init_token_b.result}"
}
