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
    os_type      = optional(string, "debian")
    unprivileged = bool
    onboot       = bool
    tags         = string
    cores        = optional(number, 1)
    memory       = number
    swap         = number
    disk_size    = string
    nic_name     = string
    bridge       = string
    vlan         = optional(number)
    ip           = string
    nameserver   = optional(string)
    gw           = string
    # Optional second NIC, e.g. for a separate VLAN/subnet. `ip` is a full
    # CIDR address (matches the primary `ip` field's format).
    nic2 = optional(object({
      nic_name = optional(string, "eth1")
      bridge   = optional(string, "vmbr0")
      vlan     = optional(number)
      ip       = string
      gw       = optional(string)
    }))
  }))
  default = {}
}

variable "machines" {
  type = map(object({
    hostname   = string
    vmid       = number
    ip         = string
    vlan       = optional(number, 0)
    template   = string
    full_clone = bool
    onboot     = bool
    ciupgrade  = optional(bool, false)
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
    # Optional second NIC, e.g. for a separate VLAN/subnet. `ip` is bare
    # (matches the primary `ip` field's format), assumed /24; gateway is only
    # configured if given, since the default route already comes from the
    # primary NIC.
    nic2 = optional(object({
      bridge = optional(string, "vmbr0")
      vlan   = optional(number)
      ip     = string
      gw     = optional(string)
    }))
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
