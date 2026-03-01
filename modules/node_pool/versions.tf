terraform {
  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = "~> 1.14"
    }
  }
  required_version = ">= 1"
  provider_meta "equinix" {
    module_name = "equinix-metal-multiarch-k8s/node_pool"
  }
}
