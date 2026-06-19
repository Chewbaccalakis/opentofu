# opentofu-proxmox

A reusable OpenTofu module library for managing Proxmox VMs and LXC containers across multiple hypervisors, with optional PHPIPAM address registration and Ansible inventory generation.

## Contents

```
modules/
  proxmox_node/   — manages VMs and LXC containers on a single Proxmox node
inventory.tpl     — Ansible inventory template consumed by the example main.tf
examples/
  site/           — complete working example of a parent site repo
```

## How to use

### 1. Add as a git submodule

From the root of your site's infrastructure repo:

```bash
git submodule add <repo-url> opentofu
git submodule update --init
```

### 2. Set up your site repo structure

The parent repo owns all site-specific configuration. This submodule is never modified per-site.

```
site-infra/
├── opentofu/            # this submodule
├── backend.tf           # state backend config
├── providers.tf         # provider declarations + one alias per hypervisor
├── main.tf              # one module block per hypervisor
├── vars.tf              # variable declarations
├── terraform.tfvars     # all site values (hypervisors, VMs, LXCs, etc.)
└── secrets.tmpl         # Infisical template for secrets (site-specific)
```

See [examples/site/](examples/site/) for a complete working example of each file.

### 3. Providers

Each Proxmox hypervisor requires its own provider alias because each has a different API endpoint. In your `providers.tf`:

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
    phpipam = {
      source  = "lord-kyron/phpipam"
      version = "1.6.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.2"
    }
  }
}

provider "proxmox" {
  alias               = "hv2"
  pm_api_url          = var.hypervisors["hv2"].api_url
  pm_api_token_id     = data.external.infisical.result["token_id"]
  pm_api_token_secret = data.external.infisical.result["hv2_token_secret"]
  pm_tls_insecure     = true
}

# Repeat for each hypervisor (hv3, hv4, ...)
```

> **Note:** OpenTofu does not currently support dynamic provider alias creation from variables. Adding or removing a hypervisor requires adding or removing a `provider` block here and a `module` block in `main.tf`. All other changes (VMs, LXCs, network config, etc.) only require edits to `terraform.tfvars`.

### 4. Module calls

In your `main.tf`, call `proxmox_node` once per hypervisor:

```hcl
module "hv2" {
  source = "./opentofu/modules/proxmox_node"

  node_name       = var.hypervisors["hv2"].node_name
  storage         = var.hypervisors["hv2"].storage
  lxc             = try(var.nodes["hv2"].lxc, {})
  machines        = try(var.nodes["hv2"].machines, {})
  enable_ipam     = var.enable_ipam
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
```

### 5. Running OpenTofu

```bash
tofu init
tofu plan
tofu apply
```

### Ansible inventory

The example `main.tf` writes a generated Ansible inventory to `../ansible/inventories/generated.yml` (relative to wherever you run `tofu` from) using `inventory.tpl` from this submodule. Adjust the `ansible_inventory_path` variable in your `terraform.tfvars` if your directory layout differs.

### State

The example `backend.tf` defaults to a local backend that stores `terraform.tfstate` in the parent repo root (one directory above the submodule). Switch to an S3/MinIO remote backend for shared or production use — the stub is included in the example.

## Module reference

### `modules/proxmox_node`

Manages VMs (`proxmox_vm_qemu`) and LXC containers (`proxmox_lxc`) on a single Proxmox node, with optional PHPIPAM address registration.

| Variable | Type | Description |
|---|---|---|
| `node_name` | `string` | Proxmox node name (e.g. `HV2`) |
| `storage` | `string` | Default storage pool (e.g. `local-lvm`) |
| `lxc` | `map(object)` | LXC container definitions (see vars for shape) |
| `machines` | `map(object)` | VM definitions (see vars for shape) |
| `enable_ipam` | `bool` | Register IPs in PHPIPAM (default `false`) |
| `subnets` | `map(string)` | CIDR → PHPIPAM subnet ID map |
| `search_domain` | `string` | DNS search domain |
| `dns_nameservers` | `string` | DNS nameserver(s) |
| `ssh_key` | `string` | SSH public key injected into all hosts |
| `ansible_user` | `string` | User created for Ansible access |
| `lxc_password` | `string` | Root password for LXC containers |

| Output | Description |
|---|---|
| `lxc_hosts` | List of `{ name, ip, vmid, filtered_tags }` for each LXC |
| `vm_hosts` | List of `{ name, ip, vmid, filtered_tags }` for each VM |
