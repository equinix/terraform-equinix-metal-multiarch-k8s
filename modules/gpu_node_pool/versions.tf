terraform {
  required_providers {
    metal = {
      source  = "equinix/metal"
      version = "2.1.0"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 0.14"
}
