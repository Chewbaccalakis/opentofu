data "phpipam_subnet" "this" {
  for_each = var.enabled ? var.network_subnets : {}

  subnet_address = split("/", each.value)[0]
  subnet_mask    = tonumber(split("/", each.value)[1])
}

locals {
  prefix_to_id = var.enabled ? {
    for name, cidr in var.network_subnets :
    "${join(".", slice(split(".", split("/", cidr)[0]), 0, 3))}." => data.phpipam_subnet.this[name].subnet_id
  } : {}
}

resource "phpipam_address" "host" {
  for_each = var.enabled ? { for h in var.hosts : h.name => h } : {}

  subnet_id   = local.prefix_to_id["${join(".", slice(split(".", each.value.ip), 0, 3))}."]
  ip_address  = each.value.ip
  hostname    = each.value.name
  description = "Managed by OpenTofu"
}
