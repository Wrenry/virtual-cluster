variable "node_name" {
  type    = string
  default = "hpc-pve"
}

variable "template_vm_id" {
  type    = number
  default = 9000
}

variable "datastore" {
  type    = string
  default = "vmpool"
}

variable "head_ip_mgmt" {
  type = string
}

variable "mgmt_gateway" {
  type    = string
  default = "172.16.202.1"
}

variable "dns_servers" {
  type = list(string)
}

variable "dns_domain" {
  type    = string
  default = null
}

variable "admin_user" {
  type    = string
  default = "wren"
}

variable "operator_ssh_pubkey" {
  type = string
}

variable "head_vcpu" {
  type    = number
  default = 4
}

variable "head_mem_mb" {
  type    = number
  default = 8192
}

variable "head_data_gb" {
  type    = number
  default = 150
}
