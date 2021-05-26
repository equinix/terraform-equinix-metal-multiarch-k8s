# Multi-Architecture Kubernetes on Equinix Metal

[![Build Status](https://github.com/equinix/terraform-metal-multiarch-k8s/workflows/Integration%20Tests/badge.svg)](https://github.com/equinix/terraform-metal-multiarch-k8s/workflows/Integration%20Tests/)

This is a [Terraform](https://registry.terraform.io/providers/equinix/metal/latest/docs) module for deploying Kubernetes on [Equinix Metal](https://metal.equinix.com) with node pools of mixed architecture--x86 and ARM- devices, and pools of GPU devices, via the `node_pool` and `gpu_node_pool` modules for managing Kubernetes nodes.  

This module can be found on the Terraform Registry at <https://registry.terraform.io/modules/equinix/multiarch-k8s/metal/latest>.

This project configures your cluster with:

- [MetalLB](https://metallb.universe.tf/) using Equinix Metal elastic IPs.

## Requirements

The only required variables are `auth_token` (your [Equinix Metal API](https://metal.equinix.com/developers/api/) key), `count_x86` (the number of x86 devices), and `count_arm` (ARM devices).

Other options include `secrets_encryption` (`"yes"` configures your controller with encryption for secrets--this is disabled by default), and fields like `facility` (the Equinix Metal location to deploy to) and `plan_x86` or `plan_arm` (to determine the server type of these architectures) can be specified as well. Refer to `vars.tf` for a complete catalog of tunable options.

## Getting Started

This module can be used by cloning the GitHub repo and making any Terraform configuration changes fit your use-case, or the module can be used as-is.

An alternative to using `git clone`, with the same affect of copying all of the Terraform config files into an empty directory, is `terraform init -from-module=equinix/multiarch-k8s/metal"`.

The following steps assume that you've chosen to use the module directly, taking advantage of the input and output variables published in the Terraform Registry.

A sample invocation of setting up this module can be found in [`examples/main.tf`](examples/main.tf).

Store the values of these two required variables in `terraform.tfvars`:

```hcl
# terraform.tfvars are used by default
# Do not check this into to source control
auth_token = "your Equinix Metal API Token"
project_id = "your Equinix Metal Project ID"
```

Run `terraform init` and the providers and modules will be fetched and initialized.

## Generating Cluster Token

Tokens for cluster authentication for your node pools to your control plane must be created before instantiating the other modules. An example of creating a new token can be found in [`examples/token.tf`](examples/token.tf).

## High Availability for Control Plane Nodes

This is not enabled by default, however, setting `control_plane_node_count` to any non-`0` value will provision a stacked control plane node and join the cluster as a master. This requires `ssh_private_key_path` be set in order to complete setup; this is used only locally to distribute certificates.

Instantiating a new controller pool just requires a new instance of the `controller_pool` module, as seen in [`examples/controller_pool.tf`](examples/controller_pool.tf).

## Node Pool Management

To instantiate a new node pool **after initial spinup**, add a second module defining the pool using the node pool module like this as seen in [`examples/new_node_pool.tf`](examples/new_node_pool.tf).

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

When destroying node pools, you must have `KUBECONFIG` set to the cluster's kubeconfig on your local `kubectl` instance in order for the cluster to [cordon, drain](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/), and delete the node from the cluster (otherwise, the node remains in a `NotReady` state, once the machine itself has been terminated).

## GPU Node Pools

The `gpu_node_pool` module provisions and configures GPU nodes for use with your Kubernetes cluster. The module definition requires `count_gpu` (defaults to "0"), and `plan_gpu` (defaults to `g2.large`). See [`examples/gpu_node_pool.tf`](examples/gpu_node_pool.tf) for usage.

and upon applying your GPU pool:

```bash
terraform apply -target=module.node_pool_gpu_green
```

You can manage this pool discretely from your mixed-architecture pools created with the `node_pool` module above.

## Applying Workloads

This project can configure your CNI and storage providers. The `workloads` map variable contains the default release of Calico for `cni`, and includes Ceph and OpenEBS. These values can be overridden in your `terraform.tfvars`. 

To use a different CNI, update `cni_cidr` to your desired network range, and `cni_workloads` to a comma-separated list of URLs, for example:

```yaml
    cni_workloads        = "https://docs.projectcalico.org/manifests/tigera-operator.yaml,https://docs.projectcalico.org/manifests/custom-resources.yaml"
```

These will be also written to `$HOME/workloads.json` on the cluster control-plane node. 

To define custom workloads upon deploy, use the `extra` key in your `workloads` map in `terraform.tfvars`:

```hcl
{
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
...
```

for example:

```hcl
...
    extra                = "https://raw.githubusercontent.com/openshift-evangelists/kbe/main/specs/deployments/d09.yaml"
  }
```

  with each subsequent workload URL separated by a comma within that string, to be applied at the end of the bootstrapping process.

