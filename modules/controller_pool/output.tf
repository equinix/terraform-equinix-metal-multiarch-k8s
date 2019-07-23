output "controller_addresses" {
  description = "Kubernetes Controller IP Addresses"
  value       = "${packet_device.k8s_primary.network.0.address}"
}

# output "controller_standby_address" {
#   description = "Control Plane Node Addresses"
#   value = "\n${join("\n${packet_device.k8s_controller_standby.*.network.0.address}")}\n"
# }
