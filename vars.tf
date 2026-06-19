variable "hypervisors" {
  description = "Per-hypervisor configuration. Keys become provider aliases (hv2, hv3, ...)."
  type = map(object({
    api_url   = string
    node_name = string
    storage   = string
  }))
}

variable "enable_ipam" {
  description = "When true, register all IPs in PHPIPAM. Requires ipam_endpoint and IPAM credentials in Infisical."
  type        = bool
  default     = false
}

variable "ipam_endpoint" {
  description = "Base URL of the PHPIPAM API, e.g. https://ipam.example.com/api"
  type        = string
  default     = ""
}

variable "network_subnets" {
  description = "Named map of CIDR ranges managed by PHPIPAM. Only used when enable_ipam = true."
  type        = map(string)
  default     = {}
}

variable "ansible_ssh_private_key_file" {
  description = "Path to the SSH private key written into the generated Ansible inventory."
  type        = string
  default     = "~/.ssh/ansible"
}

variable "ansible_inventory_path" {
  description = "Path where the generated Ansible inventory file is written. Defaults to ../ansible/inventories/generated.yml relative to this module, which points to the parent repo when used as a git submodule."
  type        = string
  default     = "../ansible/inventories/generated.yml"
}

# ── LXC variables ─────────────────────────────────────────────────────────────

variable "hv2_lxc" {
  type = map(object({
    hostname     = string
    vmid         = number
    template     = string
    unprivileged = bool
    onboot       = bool
    tags         = string
    memory       = number
    disk_size    = string
    nic_name     = string
    bridge       = string
    ip           = string
    gw           = string
  }))
  default = {}
}

variable "hv3_lxc" {
  type = map(object({
    hostname     = string
    vmid         = number
    template     = string
    unprivileged = bool
    onboot       = bool
    tags         = string
    memory       = number
    disk_size    = string
    nic_name     = string
    bridge       = string
    ip           = string
    gw           = string
  }))
  default = {}
}

variable "hv4_lxc" {
  type = map(object({
    hostname     = string
    vmid         = number
    template     = string
    unprivileged = bool
    onboot       = bool
    tags         = string
    memory       = number
    disk_size    = string
    nic_name     = string
    bridge       = string
    ip           = string
    gw           = string
  }))
  default = {}
}

variable "hv5_lxc" {
  type = map(object({
    hostname     = string
    vmid         = number
    template     = string
    unprivileged = bool
    onboot       = bool
    tags         = string
    memory       = number
    disk_size    = string
    nic_name     = string
    bridge       = string
    ip           = string
    gw           = string
  }))
  default = {}
}

# ── VM variables ───────────────────────────────────────────────────────────────

variable "hv2_machines" {
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

variable "hv3_machines" {
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

variable "hv4_machines" {
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

variable "hv5_machines" {
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

# ── Common variables ───────────────────────────────────────────────────────────

variable "ansible_user" {
  default = "ansible"
}

variable "ssh_key" {
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKuUu/BzgmmWJ64zb1moGJ+SR9D9iqGShruze/zFnwUE root@ansible"
}

variable "search_domain" {
  default = "trochalakis.com"
}

variable "dns_nameservers" {
  default = "1.1.1.1"
}
