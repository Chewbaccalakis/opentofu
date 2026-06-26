variable "enabled" {
  description = "Set to false when phpIPAM is not yet provisioned; all resources will be skipped."
  type        = bool
  default     = false
}

variable "network_subnets" {
  description = "Named map of CIDR ranges managed by phpIPAM (e.g. { lan = \"192.168.0.0/24\" })."
  type        = map(string)
  default     = {}
}

variable "hosts" {
  description = "List of hosts to register as address entries. Derive from var.nodes so values are known at plan time."
  type = list(object({
    name = string
    ip   = string
  }))
  default = []
}
