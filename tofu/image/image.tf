locals {
  cfg = yamldecode(file("${path.module}/../../classes.yml"))
}

variable "head_root_pubkey" {
  type        = string
  description = "Public key of root on the head node; lets it run Ansible on the image builder"
}

resource "proxmox_virtual_environment_vm" "image" {
  name      = "hpc-worker-image"
  node_name = var.node_name
  tags      = ["hpc", "image"]

  clone {
    vm_id        = var.template_vm_id
    datastore_id = var.datastore
    full         = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = local.cfg.network.vlan_id
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "${local.cfg.network.image_ip}/24"
      }
    }

    dns {
      servers = [local.cfg.network.head_ip]
      domain  = local.cfg.network.domain
    }

    user_account {
      username = var.admin_user
      keys     = [var.operator_ssh_pubkey, var.head_root_pubkey]
    }
  }

  stop_on_destroy = true
}

output "image_vm_id" {
  value = proxmox_virtual_environment_vm.image.vm_id
}
