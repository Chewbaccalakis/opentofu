# The SSH keypair for the ansible user lives in Infisical; the private key is
# materialized locally so the proxmox_node provisioners and the Caddy SSH
# tunnel can use it.
resource "local_sensitive_file" "ssh_private_key" {
  filename        = pathexpand("~/.ssh/infra_ansible_key")
  content_base64  = data.external.infisical.result["ssh_private_key_b64"]
  file_permission = "0600"
}

locals {
  # Flatten all declared hosts from tfvars. Derived from var.nodes (not module
  # outputs) so the values are known at plan time and for_each can use them
  # before any VMs are created.
  all_declared_hosts = flatten([
    for hv_name, hv in var.nodes : concat(
      [for name, lxc in try(hv.lxc, {}) : { name = name, ip = split("/", lxc.ip)[0] }],
      [for name, vm in try(hv.machines, {}) : { name = name, ip = split("/", vm.ip)[0] }]
    )
  ])

  # Each optional service is enabled by the presence of its credentials or
  # endpoint, so a fresh site can bootstrap in stages: provision the VMs first,
  # then flip each service on as it comes up.
  technitium_enabled = try(data.external.infisical.result["technitium_api_token"], "") != ""
  ipam_enabled       = try(data.external.infisical.result["ipam_username"], "") != ""
  caddy_enabled      = var.caddy_host != ""

  # Shared inputs passed to every proxmox_node module call.
  node_common = {
    search_domain        = var.search_domain
    dns_nameservers      = var.dns_nameservers
    ssh_key              = data.external.infisical.result["ssh_public_key"]
    ansible_user         = var.ansible_user
    lxc_password         = data.external.infisical.result["lxc_password"]
    ssh_private_key_path = local_sensitive_file.ssh_private_key.filename
  }
}

# Provider aliases must be statically declared, so each hypervisor needs its
# own module block. To add or remove a hypervisor, add/remove the corresponding
# provider alias in providers.tf and a module block here. Everything else
# (node contents, common config) lives in terraform.tfvars.

module "hv1" {
  source = "./opentofu/modules/proxmox_node"

  node_name            = var.hypervisors["hv1"].node_name
  storage              = var.hypervisors["hv1"].storage
  lxc                  = try(var.nodes["hv1"].lxc, {})
  machines             = try(var.nodes["hv1"].machines, {})
  search_domain        = local.node_common.search_domain
  dns_nameservers      = local.node_common.dns_nameservers
  ssh_key              = local.node_common.ssh_key
  ansible_user         = local.node_common.ansible_user
  lxc_password         = local.node_common.lxc_password
  ssh_private_key_path = local.node_common.ssh_private_key_path

  providers = {
    proxmox = proxmox.hv1
  }
}

locals {
  # Add an entry per hypervisor module block above.
  hv_hosts = {
    hv1 = { lxc = module.hv1.lxc_hosts, vm = module.hv1.vm_hosts }
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

# Uncomment when phpIPAM is running and credentials are in Infisical.
# module "phpipam" {
#   source = "./opentofu/modules/phpipam"
#
#   enabled         = local.ipam_enabled
#   hosts           = local.all_declared_hosts
#   network_subnets = var.network_subnets
# }

module "technitium" {
  source = "./opentofu/modules/technitium"

  enabled = local.technitium_enabled
  zone    = var.search_domain
  hosts   = local.all_declared_hosts
  zones   = var.dns_zones
  records = var.dns_records
}

module "caddy" {
  source = "./opentofu/modules/caddy"

  enabled = local.caddy_enabled
  proxies = var.caddy_proxies

  providers = {
    caddy = caddy
  }
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/${var.ansible_inventory_path}"
  content  = templatefile("${path.module}/opentofu/inventory.tpl", {
    hypervisors                  = local.hv_hosts
    tag_groups                   = local.tag_groups
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = local_sensitive_file.ssh_private_key.filename
  })
}
