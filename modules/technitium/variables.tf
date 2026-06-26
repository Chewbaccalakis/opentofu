variable "enabled" {
  description = "Set to false when the Technitium server is not yet provisioned; all resources will be skipped."
  type        = bool
  default     = false
}

variable "zone" {
  description = "Primary DNS zone to manage (e.g. lan.example.com)."
  type        = string
}

variable "hosts" {
  description = "List of hosts to register as A records. Derive from var.nodes (tfvars) so values are known at plan time."
  type = list(object({
    name = string
    ip   = string
  }))
  default = []
}

variable "ttl" {
  description = "Default TTL in seconds for managed DNS records."
  type        = number
  default     = 3600
}

variable "zones" {
  description = "Additional zones to create beyond the primary (var.zone), keyed by zone name."
  type = map(object({
    type      = optional(string, "Primary")
    forwarder = optional(string)
  }))
  default = {}
}

variable "records" {
  description = "Manually managed records. A record whose name matches an auto host in the primary zone suppresses that auto record so the two never conflict."
  type = list(object({
    zone     = string
    name     = string
    type     = string
    value    = string
    ttl      = optional(number)
    priority = optional(number)
  }))
  default = []
}
