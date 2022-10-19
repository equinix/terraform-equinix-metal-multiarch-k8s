output "controller_addresses" {
  description = "Kubernetes Controller IP Addresses"
  value       = equinix_metal_device.k8s_primary.network.0.address
}

# output "controller_standby_address" {
#   description = "Control Plane Node Addresses"
#   value = "\n${join("\n${equinix_metal_device.k8s_controller_standby.*.network.0.address}")}\n"
# }

output "kubeconfig" {
  description = "Kubeconfig content for the newly created cluster"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "kubeconfig_filename" {
  description = "Kubeconfig file for the newly created cluster"
  value       = data.local_file.kubeconfig.filename
}
