output "token" {
  value = "${random_string.kube_init_token_a.result}.${random_string.kube_init_token_b.result}"
}
