variable "auth_token" {
  type        = string
  description = "Your Equinix Metal API key"
}

variable "facility" {
  type        = string
  description = "Equinix Metal Facility"
  default     = "ewr1"
}

variable "project_id" {
  type        = string
  description = "Equinix Metal Project ID"
}

variable "plan_arm" {
  type        = string
  description = "Plan for K8s ARM Nodes"
  default     = "baremetal_2a"
}

variable "plan_x86" {
  type        = string
  description = "Plan for K8s x86 Nodes"
  default     = "c1.small.x86"
}

variable "plan_gpu" {
  type        = string
  description = "Plan for GPU equipped nodes"
  default     = "g2.large"
}

variable "plan_primary" {
  type        = string
  description = "K8s Primary Plan (Defaults to x86 - baremetal_0)"
  default     = "c1.small.x86"
}

variable "cluster_name" {
  type        = string
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
  default     = "metal-multiarch-k8s"
}

variable "count_arm" {
  type        = number
  default     = 3
  description = "Number of ARM nodes."
}

variable "count_x86" {
  type        = number
  default     = 3
  description = "Number of x86 nodes."
}

variable "count_gpu" {
  type        = number
  default     = 0
  description = "Number of GPU nodes."
}

variable "kubernetes_version" {
  type        = string
  description = "Version of Kubeadm to install"
  default     = "1.19.0-00"
}

variable "secrets_encryption" {
  type        = bool
  description = "Enable at-rest Secrets encryption"
  default     = false
}

variable "configure_ingress" {
  type        = bool
  description = "Configure Traefik"
  default     = false
}

variable "storage" {
  type        = string
  description = "Configure Storage ('ceph' or 'openebs') Operator"
  default     = "none"
}

variable "skip_workloads" {
  type        = bool
  description = "Skip Equinix Metal workloads (CSI, MetalLB)"
  default     = false
}

variable "configure_network" {
  type        = bool
  description = "Configures network for cluster"
  default     = true
}

variable "network" {
  type        = string
  description = "Configures Kube Network (flannel or calico)"
  default     = "calico"
}

variable "control_plane_node_count" {
  type        = number
  description = "Number of control plane nodes (in addition to the primary controller)"
  default     = 0
}
