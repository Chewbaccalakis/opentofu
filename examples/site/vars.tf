variable "hypervisors" {
  description = "Per-hypervisor configuration. Keys must match provider aliases in providers.tf (e.g. hv2, hv3)."
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

variable "ansible_user" {
  description = "User created on each managed host for Ansible access."
  type        = string
}

variable "ssh_key" {
  description = "SSH public key injected into all managed hosts."
  type        = string
}

variable "search_domain" {
  description = "DNS search domain set on all managed hosts."
  type        = string
}

variable "dns_nameservers" {
  description = "DNS nameserver(s) set on all managed hosts."
  type        = string
}

variable "ansible_ssh_private_key_file" {
  description = "Path to the SSH private key written into the generated Ansible inventory."
  type        = string
}

variable "ansible_inventory_path" {
  description = "Path where the generated Ansible inventory file is written. Defaults to ../ansible/inventories/generated.yml relative to this module, which points to the parent repo when used as a git submodule."
  type        = string
  default     = "../ansible/inventories/generated.yml"
}

# LXC and VM definitions per hypervisor, keyed by the same names used in
# hypervisors and providers.tf. Both lxc and machines default to {} so a node
# can be declared with only one type of workload.
variable "nodes" {
  type = map(object({
    lxc = optional(map(object({
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
    })), {})
    machines = optional(map(object({
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
    })), {})
  }))
  default = {}
}
