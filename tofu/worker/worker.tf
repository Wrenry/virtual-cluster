locals {
  cfg    = yamldecode(file("${path.module}/../../classes.yml"))
  cls    = lookup(local.cfg.classes, var.class, null)
  prefix = "vc-${var.class}-${var.request_id}"
}

variable "request_id" {
  type        = string
  description = "Four-digit request ID, e.g. 0001"
}

variable "class" {
  type        = string
  description = "Worker class from classes.yml: xs, s, m or l"
}

variable "node_count" {
  type = number
}

variable "worker_template_id" {
  type        = number
  description = "VM ID of the sealed golden worker image"
}

resource "proxmox_virtual_environment_vm" "worker" {
  count     = var.node_count
  name      = format("%s-%03d", local.prefix, count.index + 1)
  node_name = var.node_name
  tags      = ["hpc", "worker", "req-${var.request_id}", var.class]

  clone {
    vm_id = var.worker_template_id
    full  = false
  }

  agent {
    enabled = true
  }

  cpu {
    cores = try(local.cls.vcpu, 1)
    type  = "host"
  }

  memory {
    dedicated = try(local.cls.mem_gb, 1) * 1024
    floating  = 0
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = local.cfg.network.vlan_id
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dns {
      servers = [local.cfg.network.head_ip]
      domain  = local.cfg.network.domain
    }

    user_account {
      username = var.admin_user
      keys     = [var.operator_ssh_pubkey]
    }
  }

  stop_on_destroy = true

  lifecycle {
    precondition {
      condition     = local.cls != null
      error_message = "class must be one of: ${join(", ", keys(local.cfg.classes))}."
    }
    precondition {
      condition     = can(regex("^[0-9]{4}$", var.request_id))
      error_message = "request_id must be four digits, e.g. 0001."
    }
    precondition {
      condition     = var.node_count >= 1 && var.node_count <= try(local.cls.max_nodes, 0)
      error_message = "node_count must be between 1 and the class's max_nodes."
    }
  }
}

output "workers" {
  value = proxmox_virtual_environment_vm.worker[*].name
}
