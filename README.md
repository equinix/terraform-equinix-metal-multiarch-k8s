Multi-Architecture Kubernetes on Equinix Metal
==

[![Build Status](https://github.com/equinix/terraform-metal-multiarch-k8s/workflows/Integration%20Tests/badge.svg)](https://github.com/equinix/terraform-metal-multiarch-k8s/workflows/Integration%20Tests/)

This is a [Terraform](https://registry.terraform.io/providers/equinix/metal/latest/docs) module for deploying Kubernetes on [Equinix Metal](https://metal.equinix.com) with node pools of mixed architecture--x86 and ARM- devices, and pools of GPU devices, via the `node_pool` and `gpu_node_pool` modules for managing Kubernetes nodes.  

This module can be found on the Terraform Registry at <https://registry.terraform.io/modules/equinix/multiarch-k8s/metal/latest>.

This project configures your cluster with:

- [MetalLB](https://metallb.universe.tf/) using Packet elastic IPs.
- [Metal CSI](https://github.com/packethost/csi-packet) storage driver.

Requirements
-

The only required variables are `auth_token` (your [Equinix Metal API](https://metal.equinix.com/developers/api/) key), `count_x86` (the number of x86 devices), and `count_arm` (ARM devices). 

Other options include `secrets_encryption` (`"yes"` configures your controller with encryption for secrets--this is disabled by default), and fields like `facility` (the Packet location to deploy to) and `plan_x86` or `plan_arm` (to determine the server type of these architectures) can be specified as well. Refer to `vars.tf` for a complete catalog of tunable options.

Getting Started
- 

In the `examples/` directory, there are plans for a cluster token, your Kubernetes control plane, and node pool examples. 

These can be copied as-is, or you can implement these features per-module as seen in the following steps. 


Generating Cluster Token
-

Tokens for cluster authentication for your node pools to your control plane must be created before instantiating the other modules:

```
module "kube_token_1" {
  source = "./modules/kube-token"
}
```

High Availability for Control Plane Nodes
-

This is not enabled by default, however, setting `control_plane_node_count` to any non-`0` value will provision a stacked control plane node and join the cluster as a master. This requires `ssh_private_key_path` be set in order to complete setup; this is used only locally to distribute certificates.

Instantiating a new controller pool just requires a new instance of the `controller_pool` module:

```
module "controller_pool_primary" {
  source = "./modules/controller_pool"

  kube_token               = module.kube_token_1.token
  kubernetes_version       = var.kubernetes_version
  count_x86                = var.count_x86
  count_gpu                = var.count_gpu
  plan_primary             = var.plan_primary
  facility                 = var.facility
  cluster_name             = var.cluster_name
  kubernetes_lb_block      = metal_reserved_ip_block.kubernetes.cidr_notation
  project_id               = var.project_id
  auth_token               = var.auth_token
  secrets_encryption       = var.secrets_encryption
  configure_ingress        = var.configure_ingress
  ceph                     = var.ceph
  configure_network        = var.configure_network
  skip_workloads           = var.skip_workloads
  network                  = var.network
  control_plane_node_count = var.control_plane_node_count
  ssh_private_key_path     = var.ssh_private_key_path
}
```

Node Pool Management
-

To instantiate a new node pool **after initial spinup**, in `3-kube-node.tf1`, define a pool using the node pool module like this:

```hcl
module "node_pool_green" {
  source = "modules/node_pool"

  kube_token         = module.kube_token_2.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "green"
  count_x86          = var.count_x86
  count_arm          = var.count_arm
  plan_x86           = var.plan_x86
  plan_arm           = var.plan_arm
  facility           = var.facility
  cluster_name       = var.cluster_name
  controller_address = metal_device.k8s_primary.network.0.address
  project_id         = metal_project.kubernetes_multiarch.id
}
```
where the label is `green` (rather than the initial pool, `blue`) and then, generate a new `kube_token` (ensure the module name matches the `kube_token` field in the spec above, i.e. `kube_token_2`) by defining this in `1-provider.tf` (or anywhere before the node_pool instantiation):

```hcl
module "kube_token_2" {
  source = "modules/kube-token"
}
```
Generate your new token:
```
terraform apply -target=module.kube_token_2
```
On your controller, [add your new token](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-token/#cmd-token-create), and then apply the new node pool:
```
terraform apply -target=module.node_pool_green
```
At which point, you can either destroy the old pool, or taint/evict pods, etc. once this new pool connects.

GPU Node Pools
-

The `gpu_node_pool` module provisions and configures GPU nodes for use with your Kubernetes cluster. The module definition requires `count_gpu` (defaults to "0"), and `plan_gpu` (defaults to `g2.large`):

```hcl
module "node_pool_gpu_green" {
  source = "./modules/gpu_node_pool"

  kube_token         = module.kube_token_1.token
  kubernetes_version = var.kubernetes_version
  pool_label         = "gpu_green"
  count_gpu          = var.count_gpu
  plan_gpu           = var.plan_gpu
  facility           = var.facility
  cluster_name       = var.cluster_name
  controller_address = metal_device.k8s_primary.network.0.address
  project_id         = var.project_id
}
```

and upon applying your GPU pool:

```bash
terraform apply -target=module.node_pool_gpu_green
```

you can manage this pool discretely from your mixed-architecture pools created with the `node_pool` module above. 
