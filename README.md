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

## Proxmox setup

Each Proxmox node needs a dedicated API token for OpenTofu. The token ID (`user@realm!tokenname`) is shared across all nodes; each node issues its own token secret.

### 1. Create a user and role (do this once on each node, or use Datacenter-level users if your nodes are clustered)

Via the Proxmox web UI: **Datacenter → Permissions → Users → Add**

Or via the CLI on each node:

```bash
pveum user add terraform@pam --comment "OpenTofu service account"
pveum role add TerraformRole --privs \
  "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
   VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network \
   VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt \
   Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
   SDN.Use Sys.Audit Pool.Audit"
pveum aclmod / -user terraform@pam -role TerraformRole
```

> For a homelab you can simplify by assigning the built-in `PVEAdmin` role instead of creating a custom one.

### 2. Create an API token (repeat on each node)

Via the web UI: **Datacenter → Permissions → API Tokens → Add**

- User: `terraform@pam`
- Token ID: `tofu` (or any name you like)
- Uncheck **Privilege Separation** so the token inherits the user's permissions

Or via CLI:

```bash
pveum user token add terraform@pam tofu --privsep 0
```

This prints the token secret — **copy it immediately**, it is not shown again. The full token ID used by the provider is `terraform@pam!tofu`.

### 3. What goes into Infisical

| Infisical key | Value |
|---|---|
| `HV_USER` | `terraform@pam!tofu` (same for all nodes) |
| `HV2_TOKEN_SECRET` | token secret from hv2 |
| `HV3_TOKEN_SECRET` | token secret from hv3 |
| *(repeat per node)* | |
| `LXC_PASSWORD` | root password set on new LXC containers |
| `IPAM_USERNAME` | PHPIPAM username *(only if `enable_ipam = true`)* |
| `IPAM_PASSWORD` | PHPIPAM password *(only if `enable_ipam = true`)* |

---

## Infisical setup

Secrets are pulled at plan/apply time via the `infisical export` CLI command using a Go template (`secrets.tmpl`). No secrets are stored in the repo or in state.

### 1. Install the Infisical CLI

```bash
# macOS
brew install infisical/get-cli/infisical

# Linux (Debian/Ubuntu)
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | bash
apt-get install infisical
```

See [infisical.com/docs/cli](https://infisical.com/docs/cli/overview) for other platforms.

### 2. Create a project and add secrets

1. Create a project in Infisical (cloud or self-hosted)
2. In the project, open the **prod** environment
3. Create a folder called `/terraform`
4. Add the secrets listed in the table above under that path

### 3. Update secrets.tmpl with your project UUID

The first line of `secrets.tmpl` references your Infisical project by UUID:

```
{{$secrets := secret "YOUR-PROJECT-UUID-HERE" "prod" "/terraform"}}
```

Find the UUID in the Infisical URL when viewing your project:
`https://app.infisical.com/project/<uuid>/...`

Replace the placeholder in your site repo's `secrets.tmpl` with that UUID.

### 4. Authenticate and test

For interactive/local use, log in once:

```bash
infisical login
```

Then test that the template renders correctly:

```bash
infisical export --template=./secrets.tmpl
```

You should see a JSON object with all your secrets. If a key is missing from the output, check that the secret name matches exactly (case-sensitive) and is under the `/terraform` path in the `prod` environment.

### Machine identity (CI / non-interactive)

For automated runs, use an Infisical machine identity instead of a user login:

```bash
export INFISICAL_TOKEN=$(infisical login --method=universal-auth \
  --client-id=<id> --client-secret=<secret> --plain --silent)
tofu apply
```

---

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
