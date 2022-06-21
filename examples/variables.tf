variable "auth_token" {}
variable "project_id" {} # Or omit to have the module create a project.

# defaults should match the root defaults
variable "secrets_encryption" { default = false }
variable "metro" { default = "dc" }
variable "ccm_enabled" { default = false }
variable "loadbalancer_type" { default = "metallb" }
variable "control_plane_node_count" { default = 0 }
variable "count_x86" { default = 3 }
variable "count_arm" { default = 3 }
variable "kubernetes_version" { default = "1.21.0-00" }
variable "cluster_name" { default = "metal-multiarch-k8s" }
