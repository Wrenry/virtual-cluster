terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "~> 0.121.0"
    }
  }
}

provider "proxmox" {}

data "proxmox_virtual_environment_nodes" "available" {}

output "nodes" {
  value = data.proxmox_virtual_environment_nodes.available.names
}
