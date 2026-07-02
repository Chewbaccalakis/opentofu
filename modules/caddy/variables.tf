variable "enabled" {
  description = "Set to false when the Caddy server is not yet provisioned; all resources will be skipped."
  type        = bool
  default     = false
}

variable "http_listen" {
  description = "Addresses the plain-HTTP server listens on."
  type        = list(string)
  default     = [":80"]
}

variable "https_listen" {
  description = "Addresses the HTTPS server listens on."
  type        = list(string)
  default     = [":443"]
}

variable "proxies" {
  description = <<-EOT
    Reverse-proxy sites keyed by name. Each entry maps a hostname to one or more
    upstream backends (Caddy "dial" targets, e.g. "192.168.5.40:32400"). Set
    `protocol` to "https" to serve the site on the HTTPS server with automatic
    certificates (internal CA for non-public hostnames) instead of plain HTTP.
    Set `path` to restrict the route to specific request paths (e.g. ["/api/*"]).
  EOT
  type = map(object({
    host      = string
    upstreams = list(string)
    protocol  = optional(string, "http")
    path      = optional(list(string))
  }))
  default = {}

  validation {
    condition     = alltrue([for p in var.proxies : contains(["http", "https"], p.protocol)])
    error_message = "protocol must be \"http\" or \"https\"."
  }
}
