locals {
  cfg = yamldecode(file("${path.module}/../../classes.yml"))
}

resource "proxmox_virtual_environment_vm" "head" {
  name      = "hpc-head"
  node_name = var.node_name
  tags      = ["hpc", "head"]

  clone {
    vm_id        = var.template_vm_id
    datastore_id = var.datastore
    full         = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.head_vcpu
    type  = "host"
  }

  memory {
    dedicated = var.head_mem_mb
  }

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = local.cfg.network.vlan_id
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi1"
    size         = var.head_data_gb
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "${var.head_ip_mgmt}/24"
        gateway = var.mgmt_gateway
      }
    }

    ip_config {
      ipv4 {
        address = "${local.cfg.network.head_ip}/24"
      }
    }

    dns {
      servers = var.dns_servers
      domain  = var.dns_domain
    }

    user_account {
      username = var.admin_user
      keys     = [var.operator_ssh_pubkey]
    }
  }

  stop_on_destroy = true
}

output "head_ipv4" {
  value = proxmox_virtual_environment_vm.head.ipv4_addresses
}

output "head_vm_id" {
  value = proxmox_virtual_environment_vm.head.vm_id
}
