variable "auth_token" {
  type        = string
  description = "Your Equinix Metal API key"
}

variable "facility" {
  type        = string
  description = "Equinix Metal Facility"
  default     = "dc13"
}

variable "project_id" {
  type        = string
  default     = "null"
  description = "Equinix Metal Project ID"
}

variable "metal_create_project" {
  type        = bool
  default     = true
  description = "Create a Metal Project if this is 'true'. Else use provided 'project_id'"
}

variable "metal_project_name" {
  type        = string
  default     = "baremetal-multiarch-k8s"
  description = "The name of the Metal project if 'create_project' is 'true'."
}

variable "plan_arm" {
  type        = string
  description = "Plan for K8s ARM Nodes"
  default     = "c2.large.arm"
}

variable "plan_x86" {
  type        = string
  description = "Plan for K8s x86 Nodes"
  default     = "c3.small.x86"
}

variable "plan_gpu" {
  type        = string
  description = "Plan for GPU equipped nodes"
  default     = "g2.large"
}

variable "plan_primary" {
  type        = string
  description = "K8s Primary Plan"
  default     = "c3.small.x86"
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
  default     = "1.21.0-00"
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

variable "workloads" {
  type        = map(any)
  description = "Workloads to apply on provisioning (multiple manifests for a single key should be a comma-separated string)"
  default = {
    cni_cidr             = "192.168.0.0/16"
    cni_workloads        = "https://docs.projectcalico.org/manifests/tigera-operator.yaml,https://docs.projectcalico.org/manifests/custom-resources.yaml"
    ceph_common          = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/common.yaml"
    ceph_operator        = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/operator.yaml"
    ceph_cluster_minimal = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/cluster-minimal.yaml"
    ceph_cluster         = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/cluster.yaml"
    open_ebs_operator    = "https://openebs.github.io/charts/openebs-operator-1.2.0.yaml"
    metallb_namespace    = "https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/namespace.yaml"
    metallb_release      = "https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/metallb.yaml"
    ingress_controller   = "https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-ds.yaml"
    nvidia_gpu           = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml"
    extra                = ""
  }
}

variable "skip_workloads" {
  type        = bool
  description = "Skip Equinix Metal workloads (MetalLB)"
  default     = false
}

variable "control_plane_node_count" {
  type        = number
  description = "Number of control plane nodes (in addition to the primary controller)"
  default     = 0
}

variable "ccm_enabled" {
  type        = bool
  description = "Whether or not the Equnix Metal CCM will be enabled"
  default     = false
}

variable "loadbalancer_type" {
  type        = string
  description = "The type of Load Balancer to configure with the Equinix CCM"
  default     = "metallb"
}