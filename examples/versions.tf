terraform {
  required_providers {
    metal = {
      source  = "equinix/metal"
      version = ">= 2.1, <4"
    }
  }
  required_version = ">= 0.14"
}
