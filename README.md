# Multi-Architecture Kubernetes on Equinix Metal

[![Build Status](https://github.com/equinix/terraform-metal-multiarch-k8s/workflows/Integration%20Tests/badge.svg)](https://github.com/equinix/terraform-metal-multiarch-k8s/workflows/Integration%20Tests/)

This is a [Terraform](https://registry.terraform.io/providers/equinix/metal/latest/docs) module for deploying Kubernetes on [Equinix Metal](https://metal.equinix.com) with node pools of mixed architecture--x86 and ARM- devices, and pools of GPU devices, via the `node_pool` and `gpu_node_pool` modules for managing Kubernetes nodes.  

This module can be found on the Terraform Registry at <https://registry.terraform.io/modules/equinix/multiarch-k8s/metal/latest>.

This project configures your cluster with:

- [MetalLB](https://metallb.universe.tf/) using Equinix Metal elastic IPs.
- [Equinix Metal CSI](https://github.com/packethost/csi-packet) storage driver.

## Requirements

The only required variables are `auth_token` (your [Equinix Metal API](https://metal.equinix.com/developers/api/) key), `count_x86` (the number of x86 devices), and `count_arm` (ARM devices).

Other options include `secrets_encryption` (`"yes"` configures your controller with encryption for secrets--this is disabled by default), and fields like `facility` (the Equinix Metal location to deploy to) and `plan_x86` or `plan_arm` (to determine the server type of these architectures) can be specified as well. Refer to `vars.tf` for a complete catalog of tunable options.

## Getting Started

This module can be used by cloning the GitHub repo and making any Terraform configuration changes fit your use-case, or the module can be used as-is.

An alternative to using `git clone`, with the same affect of copying all of the Terraform config files into an empty directory, is `terraform init -from-module=equinix/multiarch-k8s/metal"`.

The following steps assume that you've chosen to use the module directly, taking advantage of the input and output variables published in the Terraform Registry.

Create a file called `main.tf` with the following contents:

```hcl
# main.tf
variable "auth_token" {}
variable "project_id" {}

module "multiarch-k8s" {
  source  = "equinix/multiarch-k8s/metal"
  version = "0.1.0" # Use the latest version, according to https://github.com/equinix/terraform-metal-multiarch-k8s/releases

  # In a production
  auth_token = var.auth_token
  project_id = var.project_id
}
```

Store the values of these two required variables in `terraform.tfvars`:

```hcl
# terraform.tfvars are used by default
# Do not check this into to source control
auth_token = "your Equinix Metal API Token"
project_id = "your Equinix Metal Project ID"
```

Run `terraform init` and the providers and modules will be fetched and initialized.

## Generating Cluster Token

Tokens for cluster authentication for your node pools to your control plane must be created before instantiating the other modules:

```hcl
module "kube_token_1" {
  # source = "./modules/kube-token"
}
```

## High Availability for Control Plane Nodes

This is not enabled by default, however, setting `control_plane_node_count` to any non-`0` value will provision a stacked control plane node and join the cluster as a master. This requires `ssh_private_key_path` be set in order to complete setup; this is used only locally to distribute certificates.

Instantiating a new controller pool just requires a new instance of the `controller_pool` module:

```hcl
module "controller_pool_primary" {
  source = "equinix/multiarch-k8s/metal/modules/controller_pool"

  # Or if the modules are copied locally:
  # source = "./modules/controller_pool"

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

## Node Pool Management

To instantiate a new node pool **after initial spinup**, add a second module defining the pool using the node pool module like this:

```hcl
module "node_pool_green" {
  source = "equinix/multiarch-k8s/metal/modules/node_pool"

  # Or if the modules are copied locally:
  # source = "./modules/node_pool"

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

module "kube_token_2" {
  source = "modules/kube-token"
}
```

In this example, the label is `green` (rather than the initial pool, `blue`) and then, generate a new `kube_token` (ensure the module name matches the `kube_token` field in the spec above, i.e. `kube_token_2`) by defining this in `1-provider.tf` (or anywhere before the node_pool instantiation):

Generate your new token:

```sh
terraform apply -target=module.kube_token_2
```

On your controller, [add your new token](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-token/#cmd-token-create), and then apply the new node pool:

```sh
terraform apply -target=module.node_pool_green
```

At which point, you can either destroy the old pool, or taint/evict pods, etc. once this new pool connects.

## GPU Node Pools

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

You can manage this pool discretely from your mixed-architecture pools created with the `node_pool` module above.
