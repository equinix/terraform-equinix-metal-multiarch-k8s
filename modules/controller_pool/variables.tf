variable "kube_token" {
  type        = string
  description = "A token that kubeadm will use during bootstraping, capable of adding new nodes to the cluster."
}

variable "kubernetes_version" {
  type        = string
  description = "Version of Kubeadm to install"
}

variable "facility" {
  type        = string
  description = "Equinix Metal Facility"
}

variable "cluster_name" {
  type        = string
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
}

variable "project_id" {
  type        = string
  description = "Equinix Metal Project ID"
}

variable "auth_token" {
  type        = string
  description = "Your Equinix Metal API token"
}

variable "secrets_encryption" {
  type        = bool
  description = "Enable at-rest Secrets encryption"
}

variable "storage" {
  type        = string
  description = "Configure Storage ('ceph' or 'openebs') Operator"
}

variable "configure_network" {
  type        = bool
  description = "Configures network for cluster"
}

variable "configure_ingress" {
  type        = bool
  description = "Configure Traefik"
}

variable "skip_workloads" {
  type        = bool
  description = "Skip Equinix Metal workloads (CSI, MetalLB)"
}

variable "network" {
  type        = string
  description = "Configures Kube Network (flannel or calico)"
}

variable "plan_primary" {
  type        = string
  description = "K8s Primary Plan (Defaults to x86 - baremetal_0)"
}

variable "count_x86" {
  type        = number
  description = "Number of x86 nodes."
}

variable "count_gpu" {
  type        = number
  description = "Number of GPU nodes."
}

variable "kubernetes_lb_block" {
  type        = string
  description = "CIDR of addresses to assign to the LoadBalancer"
}

variable "control_plane_node_count" {
  type        = number
  description = "Number of control plane nodes (in addition to the primary controller)"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to SSH Private key to access the nodes"
}

variable "workloads" {
  type        = map
  description = "Workloads to be applied during provisioning."
}