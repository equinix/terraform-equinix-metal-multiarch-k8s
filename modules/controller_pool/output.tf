output "controller_addresses" {
  description = "Kubernetes Controller IP Addresses"
  value       = "${packet_device.k8s_primary.network.0.address}"
}
