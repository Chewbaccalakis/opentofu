locals {
  # The primary (search-domain) zone is always managed here; merge in any extras
  # declared in tfvars so records can target either.
  all_zones = merge(
    { (var.zone) = { type = "Primary", forwarder = null } },
    var.zones
  )

  # Host labels the user manages by hand in the primary zone. The auto host
  # records skip these so a manual record never conflicts with an auto one.
  manual_primary_names = toset([
    for r in var.records : r.name
    if r.zone == var.zone && contains(["A", "AAAA", "CNAME"], r.type)
  ])
}

resource "technitium_dns_zone" "this" {
  for_each = var.enabled ? local.all_zones : {}

  name      = each.key
  type      = each.value.type
  forwarder = try(each.value.forwarder, null)
}

resource "technitium_dns_zone_record" "hosts" {
  for_each = var.enabled ? {
    for h in var.hosts : h.name => h
    if !contains(local.manual_primary_names, h.name)
  } : {}

  zone       = var.zone
  domain     = "${each.value.name}.${var.zone}"
  type       = "A"
  ttl        = var.ttl
  ip_address = each.value.ip

  depends_on = [technitium_dns_zone.this]
}

resource "technitium_dns_zone_record" "custom" {
  # Keyed by zone/name/type/value so multi-value records (round-robin A, multiple
  # MX) don't collide on the same map key.
  for_each = var.enabled ? {
    for r in var.records : "${r.zone}/${r.name}/${r.type}/${r.value}" => r
  } : {}

  zone   = each.value.zone
  domain = each.value.name == "@" ? each.value.zone : "${each.value.name}.${each.value.zone}"
  type   = each.value.type
  ttl    = coalesce(each.value.ttl, var.ttl)

  ip_address  = contains(["A", "AAAA"], each.value.type) ? each.value.value : null
  cname       = each.value.type == "CNAME" ? each.value.value : null
  name_server = each.value.type == "NS" ? each.value.value : null
  text        = each.value.type == "TXT" ? each.value.value : null
  exchange    = each.value.type == "MX" ? each.value.value : null
  preference  = each.value.type == "MX" ? each.value.priority : null

  depends_on = [technitium_dns_zone.this]
}
