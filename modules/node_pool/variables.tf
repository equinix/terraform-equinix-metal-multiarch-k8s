
variable "kube_token" {
  type        = string
  description = "Your Kubernetes token"
}

variable "kubernetes_version" {
  type        = string
  description = "Version of Kubeadm to install"
}

variable "pool_label" {
  type        = string
  description = "Label for the node pool"
}

variable "count_x86" {
  type        = number
  description = "Number of x86 nodes."
}

variable "count_arm" {
  type        = number
  description = "Number of ARM nodes."
}

variable "plan_x86" {
  type        = string
  description = "Plan for K8s x86 Nodes"
}

variable "plan_arm" {
  type        = string
  description = "Plan for K8s ARM Nodes"
}

variable "facility" {
  type        = string
  description = "Equinix Metal Facility"
}

variable "cluster_name" {
  type        = string
  description = "Name of your cluster. Alpha-numeric and hyphens only, please."
}

variable "controller_address" {
  type        = string
  description = "Address to the Kubernetes Controller"
}

variable "project_id" {
  type        = string
  description = "Equinix Metal Project ID"
}

variable "storage" {
  type        = string
  description = "Configure Storage ('ceph' or 'openebs') Operator"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to SSH Private key to access the nodes"
}

