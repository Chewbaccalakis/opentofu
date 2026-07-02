locals {
  # Split proxies across the two servers by protocol. Caddy applies automatic
  # HTTPS (cert provisioning) only to the server on the HTTPS port; the :80
  # server serves plain HTTP.
  http_proxies  = var.enabled ? { for k, v in var.proxies : k => v if v.protocol == "http" } : {}
  https_proxies = var.enabled ? { for k, v in var.proxies : k => v if v.protocol == "https" } : {}
}

resource "caddy_server" "http" {
  count = length(local.http_proxies) > 0 ? 1 : 0

  name   = "http"
  listen = var.http_listen

  # One terminal route per proxy site: match on hostname (optionally path) and
  # hand off to the reverse_proxy handler with one upstream per backend.
  dynamic "route" {
    for_each = local.http_proxies
    content {
      terminal = true

      match {
        host = [route.value.host]
        path = route.value.path
      }

      handle {
        reverse_proxy {
          dynamic "upstream" {
            for_each = route.value.upstreams
            content {
              dial = upstream.value
            }
          }
        }
      }
    }
  }
}

resource "caddy_server" "https" {
  count = length(local.https_proxies) > 0 ? 1 : 0

  name   = "https"
  listen = var.https_listen

  dynamic "route" {
    for_each = local.https_proxies
    content {
      terminal = true

      match {
        host = [route.value.host]
        path = route.value.path
      }

      handle {
        reverse_proxy {
          dynamic "upstream" {
            for_each = route.value.upstreams
            content {
              dial = upstream.value
            }
          }
        }
      }
    }
  }
}
