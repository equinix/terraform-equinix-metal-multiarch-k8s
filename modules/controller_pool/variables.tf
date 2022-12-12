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
  description = "Equinix Metal Facility (conflicts with metro)"
}

variable "metro" {
  type        = string
  description = "Equinix Metal Metro (conflicts with facility)"
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
  sensitive   = true
}

variable "secrets_encryption" {
  type        = bool
  description = "Enable at-rest Secrets encryption"
}

variable "storage" {
  type        = string
  description = "Configure Storage ('ceph' or 'openebs') Operator"
}

variable "configure_ingress" {
  type        = bool
  description = "Configure Traefik"
}

variable "skip_workloads" {
  type        = bool
  description = "Skip Equinix Metal workloads (CSI, MetalLB)"
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
  type        = map(any)
  description = "Workloads to be applied during provisioning."
}

variable "metallb_namespace" {
  type        = string
  description = "The namespace where metallb is installed"
  default     = "metallb-system"
}

variable "metallb_configmap" {
  type        = string
  description = "The name of the metallb configmap to create"
  default     = "config"
}

variable "ccm_enabled" {
  type        = bool
  description = "Whether or not the Equnix Metal CCM will be enabled"
  default     = false
}

variable "ccm_version" {
  type        = string
  description = "The semver formatted version of the Equinix Metal CCM"
  default     = "v3.2.2"
}

variable "loadbalancer_type" {
  type        = string
  description = "The type of Load Balancer to configure with the Equinix CCM"
  default     = "metallb"
}

variable "prerequisites" {
  type        = list(any)
  description = "cloud-init configuration that must be run on nodes when they are provisioned.  Must be a list of objects conforming to the `part` schema documented for the `cloudinit_config` resource: https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/cloudinit_config."
  default     = []
}