variable "auth_token" {
  description = "Your Packet API key"
}

variable "facility" {
  description = "Packet Facility"
  default     = "ewr1"
}

variable "plan_arm" {
  description = "Plan for K8s ARM Nodes"
  default     = "baremetal_2a"
}

variable "plan_x86" {
  description = "Plan for K8s x86 Nodes"
  default     = "baremetal_0"
}

variable "plan_primary" {
  description = "K8s Primary Plan (Defaults to x86 - baremetal_0)"
  default     = "baremetal_0"
}

variable "cluster_name" {
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "packet-multiarch-k8s"
}

variable "count_arm" {
  default     = "3"
  description = "Number of ARM nodes."
}

variable "count_x86" {
  default     = "3"
  description = "Number of x86 nodes."
}

variable "kubernetes_version" {
  description = "Version of Kubeadm to install"
  default     = "1.12.3-00"
}

variable "secrets_encryption" {
  description = "Enable at-rest Secrets encryption"
  default     = "no"
}
