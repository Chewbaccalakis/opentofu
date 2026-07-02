data "phpipam_subnet" "subnets" {
  for_each = var.enable_ipam ? var.network_subnets : {}

  subnet_address = split("/", each.value)[0]
  subnet_mask    = tonumber(split("/", each.value)[1])
}

locals {
  subnets = var.enable_ipam ? {
    for name, cidr in var.network_subnets :
    cidr => data.phpipam_subnet.subnets[name].subnet_id
  } : {}

  # Shared inputs passed to every proxmox_node module call.
  node_common = {
    enable_ipam     = var.enable_ipam
    subnets         = local.subnets
    search_domain   = var.search_domain
    dns_nameservers = var.dns_nameservers
    ssh_key         = var.ssh_key
    ansible_user    = var.ansible_user
    lxc_password    = data.external.infisical.result["lxc_password"]
  }
}

# Provider aliases must be statically declared, so each hypervisor needs its
# own module block. To add or remove a hypervisor, add/remove the corresponding
# provider alias in providers.tf and a module block here. Everything else
# (node contents, common config) lives in the parent repo's terraform.tfvars.

module "hv2" {
  source = "./opentofu/modules/proxmox_node"

  node_name       = var.hypervisors["hv2"].node_name
  storage         = var.hypervisors["hv2"].storage
  lxc             = try(var.nodes["hv2"].lxc, {})
  machines        = try(var.nodes["hv2"].machines, {})
  enable_ipam     = local.node_common.enable_ipam
  subnets         = local.node_common.subnets
  search_domain   = local.node_common.search_domain
  dns_nameservers = local.node_common.dns_nameservers
  ssh_key         = local.node_common.ssh_key
  ansible_user    = local.node_common.ansible_user
  lxc_password    = local.node_common.lxc_password

  providers = {
    proxmox = proxmox.hv2
    phpipam = phpipam
  }
}

module "hv3" {
  source = "./opentofu/modules/proxmox_node"

  node_name       = var.hypervisors["hv3"].node_name
  storage         = var.hypervisors["hv3"].storage
  lxc             = try(var.nodes["hv3"].lxc, {})
  machines        = try(var.nodes["hv3"].machines, {})
  enable_ipam     = local.node_common.enable_ipam
  subnets         = local.node_common.subnets
  search_domain   = local.node_common.search_domain
  dns_nameservers = local.node_common.dns_nameservers
  ssh_key         = local.node_common.ssh_key
  ansible_user    = local.node_common.ansible_user
  lxc_password    = local.node_common.lxc_password

  providers = {
    proxmox = proxmox.hv3
    phpipam = phpipam
  }
}

module "hv4" {
  source = "./opentofu/modules/proxmox_node"

  node_name       = var.hypervisors["hv4"].node_name
  storage         = var.hypervisors["hv4"].storage
  lxc             = try(var.nodes["hv4"].lxc, {})
  machines        = try(var.nodes["hv4"].machines, {})
  enable_ipam     = local.node_common.enable_ipam
  subnets         = local.node_common.subnets
  search_domain   = local.node_common.search_domain
  dns_nameservers = local.node_common.dns_nameservers
  ssh_key         = local.node_common.ssh_key
  ansible_user    = local.node_common.ansible_user
  lxc_password    = local.node_common.lxc_password

  providers = {
    proxmox = proxmox.hv4
    phpipam = phpipam
  }
}

module "hv5" {
  source = "./opentofu/modules/proxmox_node"

  node_name       = var.hypervisors["hv5"].node_name
  storage         = var.hypervisors["hv5"].storage
  lxc             = try(var.nodes["hv5"].lxc, {})
  machines        = try(var.nodes["hv5"].machines, {})
  enable_ipam     = local.node_common.enable_ipam
  subnets         = local.node_common.subnets
  search_domain   = local.node_common.search_domain
  dns_nameservers = local.node_common.dns_nameservers
  ssh_key         = local.node_common.ssh_key
  ansible_user    = local.node_common.ansible_user
  lxc_password    = local.node_common.lxc_password

  providers = {
    proxmox = proxmox.hv5
    phpipam = phpipam
  }
}

locals {
  hv_hosts = {
    hv2 = { lxc = module.hv2.lxc_hosts, vm = module.hv2.vm_hosts }
    hv3 = { lxc = module.hv3.lxc_hosts, vm = module.hv3.vm_hosts }
    hv4 = { lxc = module.hv4.lxc_hosts, vm = module.hv4.vm_hosts }
    hv5 = { lxc = module.hv5.lxc_hosts, vm = module.hv5.vm_hosts }
  }

  all_hosts = flatten([
    for hv_name, hv in local.hv_hosts : [
      for h in concat(hv.lxc, hv.vm) : [
        for tag in h.filtered_tags : {
          tag  = tag
          name = h.name
          ip   = h.ip
          vmid = h.vmid
        }
      ]
    ]
  ])

  tag_groups = {
    for tag in distinct([for h in local.all_hosts : h.tag]) :
    tag => [
      for h in local.all_hosts : {
        name = h.name
        ip   = h.ip
        vmid = h.vmid
      } if h.tag == tag
    ]
  }
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/${var.ansible_inventory_path}"
  content  = templatefile("${path.module}/opentofu/inventory.tpl", {
    hypervisors                  = local.hv_hosts
    tag_groups                   = local.tag_groups
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
  })
}

module "caddy" {
  source = "./opentofu/modules/caddy"

  enabled = var.caddy_enabled
  proxies = var.caddy_proxies

  providers = {
    caddy = caddy
  }
}
