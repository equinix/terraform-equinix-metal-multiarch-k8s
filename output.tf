output "Kubernetes_Cluster_Info" {
  value = "\n\n Run: \n\n\t `ssh root@${packet_device.k8s_primary.network.0.address} kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -w` \n\n To troubleshoot (or monitor) spin-up, check the cloud-init output:\n\n\t `ssh root@${packet_device.k8s_primary.network.0.address} tail -f /var/log/cloud-init-output.log` \n\n The initialization and spin-up process may take 5-7 minutes to complete."
}
