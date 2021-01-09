terraform {
  required_providers {
    metal = {
      source  = "equinix/metal"
      version = "1.0.0"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 0.13"
}
