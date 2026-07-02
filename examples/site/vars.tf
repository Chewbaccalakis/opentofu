variable "hypervisors" {
  description = "Per-hypervisor configuration. Keys must match provider aliases in providers.tf (e.g. hv1, hv2)."
  type = map(object({
    api_url   = string
    node_name = string
    storage   = string
  }))
}

variable "ipam_endpoint" {
  description = "Base URL of the PHPIPAM API, e.g. https://ipam.example.com/api"
  type        = string
  default     = ""
}

variable "network_subnets" {
  description = "Named map of CIDR ranges managed by PHPIPAM. Only used when the phpipam module is enabled."
  type        = map(string)
  default     = {}
}

variable "ansible_user" {
  description = "User created on each managed host for Ansible access."
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

variable "technitium_host" {
  description = "URL of the Technitium DNS Server API (e.g. http://192.168.0.2:5380). Required once Technitium is running."
  type        = string
  default     = ""
}

variable "dns_zones" {
  description = "Additional Technitium DNS zones to create, beyond the auto-managed search_domain zone. Keyed by zone name."
  type = map(object({
    type      = optional(string, "Primary")
    forwarder = optional(string)
  }))
  default = {}
}

variable "dns_records" {
  description = "Manually managed DNS records. Each targets a zone by name (the search_domain zone or one from dns_zones). A record in the search_domain zone whose name matches an auto-added host replaces that host record instead of conflicting with it."
  type = list(object({
    zone     = string
    name     = string           # subdomain label, or "@" for the zone apex
    type     = string           # A, AAAA, CNAME, NS, TXT, MX
    value    = string           # IP / target / text / mail exchanger
    ttl      = optional(number)
    priority = optional(number) # required for MX records
  }))
  default = []
}

variable "caddy_host" {
  description = "Caddy admin API endpoint. When using the SSH tunnel this is the endpoint as seen from the caddy host (e.g. http://localhost:2019). Leave empty to disable Caddy management."
  type        = string
  default     = ""
}

variable "caddy_ssh_host" {
  description = "SSH target (user@host:port) used to tunnel to the Caddy admin API. Empty to reach caddy_host directly."
  type        = string
  default     = ""
}

variable "caddy_ssh_host_key" {
  description = "SSH host key of the caddy host, known_hosts format (get it with: ssh-keyscan <ip>). Required when caddy_ssh_host is set."
  type        = string
  default     = ""
}

variable "caddy_proxies" {
  description = "Reverse-proxy sites keyed by name. Each maps a hostname to one or more upstream backends (Caddy dial targets, e.g. \"192.168.0.40:32400\"). protocol picks plain HTTP on :80 (default) or HTTPS on :443 with automatic certificates. Set path to restrict the route to specific request paths."
  type = map(object({
    host      = string
    upstreams = list(string)
    protocol  = optional(string, "http")
    path      = optional(list(string))
  }))
  default = {}
}

variable "ansible_inventory_path" {
  description = "Path where the generated Ansible inventory file is written, relative to the repo root."
  type        = string
  default     = "./ansible/inventories/generated.yml"
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
      swap         = number
      disk_size    = string
      nic_name     = string
      bridge       = string
      ip           = string
      nameserver   = optional(string)
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
    })), {})
  }))
  default = {}
}
