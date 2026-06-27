variable "node_name" {
  type = string
}

# "local-lvm" for HV2/3/4, "local-zfs" for HV5
variable "storage" {
  type = string
}

variable "lxc" {
  type = map(object({
    hostname     = string
    vmid         = number
    template     = string
    unprivileged = bool
    onboot       = bool
    tags         = string
    memory       = number
    swap         = number
    disk_size    = string
    nic_name     = string
    bridge       = string
    ip           = string
    gw           = string
  }))
  default = {}
}

variable "machines" {
  type = map(object({
    hostname   = string
    vmid       = number
    ip         = string
    ip2        = optional(string, null)
    vlan       = optional(number, 0)
    template   = string
    full_clone = bool
    onboot     = bool
    ciupgrade  = optional(string, "false")
    tags       = string
    agent      = number
    memory     = number
    disk_size  = optional(string, "32")
    balloon    = number
    cpu_type   = string
    cores      = number
    sockets    = number
    vcpus      = number
    bios       = string
    machine    = string
    bridge     = string
  }))
  default = {}
}

variable "search_domain" {
  type = string
}

variable "dns_nameservers" {
  type = string
}

variable "ssh_key" {
  type = string
}

variable "ansible_user" {
  type = string
}

variable "lxc_password" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_path" {
  type = string
}
