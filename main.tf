# Subnet IDs are only fetched when IPAM is enabled. The for_each key becomes
# the name used to look up IDs in local.subnets.
data "phpipam_subnet" "subnets" {
  for_each = var.enable_ipam ? var.network_subnets : {}

  subnet_address = split("/", each.value)[0]
  subnet_mask    = tonumber(split("/", each.value)[1])
}

locals {
  # Map of CIDR → phpipam subnet_id, empty when IPAM is disabled.
  subnets = var.enable_ipam ? {
    for name, cidr in var.network_subnets :
    cidr => data.phpipam_subnet.subnets[name].subnet_id
  } : {}
}

module "hv2" {
  source = "./modules/proxmox_node"

  node_name       = var.hypervisors["hv2"].node_name
  storage         = var.hypervisors["hv2"].storage
  enable_ipam     = var.enable_ipam
  lxc             = var.hv2_lxc
  machines        = var.hv2_machines
  subnets         = local.subnets
  search_domain   = var.search_domain
  dns_nameservers = var.dns_nameservers
  ssh_key         = var.ssh_key
  ansible_user    = var.ansible_user
  lxc_password    = data.external.infisical.result["lxc_password"]

  providers = {
    proxmox = proxmox.hv2
    phpipam = phpipam
  }
}

module "hv3" {
  source = "./modules/proxmox_node"

  node_name       = var.hypervisors["hv3"].node_name
  storage         = var.hypervisors["hv3"].storage
  enable_ipam     = var.enable_ipam
  lxc             = var.hv3_lxc
  machines        = var.hv3_machines
  subnets         = local.subnets
  search_domain   = var.search_domain
  dns_nameservers = var.dns_nameservers
  ssh_key         = var.ssh_key
  ansible_user    = var.ansible_user
  lxc_password    = data.external.infisical.result["lxc_password"]

  providers = {
    proxmox = proxmox.hv3
    phpipam = phpipam
  }
}

module "hv4" {
  source = "./modules/proxmox_node"

  node_name       = var.hypervisors["hv4"].node_name
  storage         = var.hypervisors["hv4"].storage
  enable_ipam     = var.enable_ipam
  lxc             = var.hv4_lxc
  machines        = var.hv4_machines
  subnets         = local.subnets
  search_domain   = var.search_domain
  dns_nameservers = var.dns_nameservers
  ssh_key         = var.ssh_key
  ansible_user    = var.ansible_user
  lxc_password    = data.external.infisical.result["lxc_password"]

  providers = {
    proxmox = proxmox.hv4
    phpipam = phpipam
  }
}

module "hv5" {
  source = "./modules/proxmox_node"

  node_name       = var.hypervisors["hv5"].node_name
  storage         = var.hypervisors["hv5"].storage
  enable_ipam     = var.enable_ipam
  lxc             = var.hv5_lxc
  machines        = var.hv5_machines
  subnets         = local.subnets
  search_domain   = var.search_domain
  dns_nameservers = var.dns_nameservers
  ssh_key         = var.ssh_key
  ansible_user    = var.ansible_user
  lxc_password    = data.external.infisical.result["lxc_password"]

  providers = {
    proxmox = proxmox.hv5
    phpipam = phpipam
  }
}

locals {
  # Single map consumed by both tag_groups and the inventory template.
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
  filename = "${path.module}/../ansible/inventories/generated.yml"
  content  = templatefile("${path.module}/inventory.tpl", {
    hypervisors                  = local.hv_hosts
    tag_groups                   = local.tag_groups
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
  })
}
