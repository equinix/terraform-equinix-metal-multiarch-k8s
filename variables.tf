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
  description = "Equinix Metal Project ID"
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
  type        = map
  description = "Workloads to apply on provisioning"
  default = {
    ceph_common          = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/common.yaml"
    ceph_operator        = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/operator.yaml"
    ceph_cluster_minimal = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/cluster-minimal.yaml"
    ceph_cluster         = "https://raw.githubusercontent.com/rook/rook/release-1.0/cluster/examples/kubernetes/ceph/cluster.yaml"
    open_ebs_operator    = "https://openebs.github.io/charts/openebs-operator-1.2.0.yaml"
    tigera_operator      = "https://docs.projectcalico.org/manifests/tigera-operator.yaml"
    calico               = "https://docs.projectcalico.org/manifests/custom-resources.yaml"
    flannel              = "https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml"
    metallb_namespace    = "https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/namespace.yaml"
    metallb_release      = "https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/metallb.yaml"
    traefik              = "https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-ds.yaml"
    nvidia_gpu           = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml"
  }
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
