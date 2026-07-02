# opentofu-proxmox

A reusable OpenTofu module library for a Proxmox-based homelab: VMs and LXC containers across one or more hypervisors, DNS records in Technitium, reverse-proxy routes in Caddy, optional phpIPAM address registration, and Ansible inventory generation.

## Contents

```
modules/
  proxmox_node/   — VMs and LXC containers on a single Proxmox node
  technitium/     — DNS zones and records on a Technitium DNS server
  caddy/          — reverse-proxy routes on a Caddy server (via its admin API)
  phpipam/        — address registration in phpIPAM
inventory.tpl     — Ansible inventory template consumed by the site main.tf
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
├── ansible/             # playbooks; inventory is generated here by tofu
├── backend.tf           # state backend config
├── providers.tf         # provider declarations + one alias per hypervisor
├── main.tf              # module blocks + shared locals
├── vars.tf              # variable declarations
├── terraform.tfvars     # all site values (hypervisors, VMs, LXCs, DNS, proxies)
└── secrets.tmpl         # Infisical template for secrets (site-specific)
```

See [examples/site/](examples/site/) for a complete working example of each file.

### 3. Staged bootstrap

A fresh site can't run everything at once — Technitium and Caddy run *on* hosts this config creates. Each service module therefore gates itself on the presence of its credentials or endpoint and no-ops until then:

| Module | Enabled when |
|---|---|
| `proxmox_node` | always |
| `technitium` | `TECHNITIUM_API_TOKEN` exists in Infisical |
| `caddy` | `caddy_host` is set in `terraform.tfvars` |
| `phpipam` | `IPAM_USERNAME` exists in Infisical (module block commented out by default) |

The intended order: apply to create the LXCs/VMs → configure the services on them with Ansible → add the token/endpoint → apply again to start managing their contents.

### 4. Providers

Each Proxmox hypervisor requires its own provider alias because each has a different API endpoint. Adding or removing a hypervisor requires a `provider` block in `providers.tf`, a `module` block in `main.tf`, an entry in `local.hv_hosts`, and its token secret in `secrets.tmpl`. All other changes (VMs, LXCs, DNS records, proxy routes) only touch `terraform.tfvars`.

The Technitium and Caddy providers pass a placeholder credential / default endpoint until the real one exists, so `plan` works before those services are up. See [examples/site/providers.tf](examples/site/providers.tf).

### 5. Running OpenTofu

Secrets are injected at run time by the Infisical CLI:

```bash
tofu init
infisical run --path /terraform -- tofu plan -out plan
infisical run --path /terraform -- tofu apply plan
```

### Ansible inventory

`main.tf` writes a generated Ansible inventory (grouped by hypervisor and by VM/LXC tag) to `ansible/inventories/generated.yml` in the parent repo, using `inventory.tpl` from this submodule. Adjust `ansible_inventory_path` in `terraform.tfvars` if your layout differs.

### State

The example `backend.tf` defaults to a local backend. Switch to an S3-compatible remote backend (MinIO, Garage, …) for anything shared — the stub is included in the example.

---

## Proxmox setup

Each Proxmox node needs a dedicated API token for OpenTofu. The token ID (`user@realm!tokenname`) is shared across all nodes; each node issues its own token secret.

### 1. Create a user and role (once per node, or Datacenter-level if clustered)

Via the Proxmox web UI: **Datacenter → Permissions → Users → Add**, or via CLI:

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

Via the web UI: **Datacenter → Permissions → API Tokens → Add** (uncheck **Privilege Separation**), or via CLI:

```bash
pveum user token add terraform@pam tofu --privsep 0
```

This prints the token secret — **copy it immediately**, it is not shown again. The full token ID used by the provider is `terraform@pam!tofu`.

### 3. What goes into Infisical

| Infisical key | Value |
|---|---|
| `HV_USER` | `terraform@pam!tofu` (same for all nodes) |
| `HV1_TOKEN_SECRET` | token secret from hv1 |
| *(repeat per node)* | |
| `LXC_PASSWORD` | root password set on new LXC containers |
| `SSH_PRIVATE_KEY` | base64-encoded private key for the ansible user |
| `SSH_PUBLIC_KEY` | matching public key, injected into all managed hosts |
| `TECHNITIUM_API_TOKEN` | Technitium API token *(add once Technitium is up — enables the technitium module)* |
| `IPAM_USERNAME` | phpIPAM username *(only if using phpipam)* |
| `IPAM_PASSWORD` | phpIPAM password *(only if using phpipam)* |

---

## Infisical setup

Secrets are pulled at plan/apply time via `infisical export` using a Go template (`secrets.tmpl`). No secrets are stored in the repo or in state (except the materialized SSH private key file and values that providers place in state — protect your state accordingly).

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

### 4. Authenticate and test

```bash
infisical login
infisical export --template=./secrets.tmpl
```

You should see a JSON object with all your secrets. If a key is missing, check that the secret name matches exactly (case-sensitive) and is under the `/terraform` path in the `prod` environment.

### Machine identity (CI / non-interactive)

```bash
export INFISICAL_TOKEN=$(infisical login --method=universal-auth \
  --client-id=<id> --client-secret=<secret> --plain --silent)
tofu apply
```

---

## Caddy setup

The `caddy` module drives Caddy's [admin API](https://caddyserver.com/docs/api) through the [`conradludgate/caddy`](https://registry.terraform.io/providers/conradludgate/caddy/latest) provider. Reverse-proxy sites are plain map entries in `terraform.tfvars`:

```hcl
caddy_proxies = {
  wiki = {
    host      = "wiki.example.lan"
    upstreams = ["192.168.1.20:8080"]     # several upstreams = load balancing
  }
  secure = {
    host      = "secure.example.lan"
    upstreams = ["192.168.1.21:80"]
    protocol  = "https"                   # default is "http"
  }
}
```

The module maintains two Caddy servers: `http` on `:80` (plain HTTP, no automatic HTTPS) and `https` on `:443` (automatic certificates). Each is only created when it has at least one site. Non-public hostnames (`.lan` etc.) can't get public certificates, so HTTPS sites use Caddy's internal CA — trust its root cert (`/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt` on the Caddy host) on your devices to avoid warnings.

### Reaching the admin API

The recommended setup keeps the admin API on the Caddy host's loopback and tunnels to it over SSH:

```hcl
caddy_host         = "http://localhost:2019"        # as seen from the caddy host
caddy_ssh_host     = "ansible@192.168.1.5:22"
caddy_ssh_host_key = "192.168.1.5 ecdsa-sha2-nistp256 AAAA..."
```

Notes:

- `caddy_ssh_host_key` pins the host's SSH key (get it with `ssh-keyscan <ip>`). It must be the **ECDSA** line: the provider's Go SSH client prefers `ecdsa-sha2-nistp256` during negotiation and does an exact match on the key received. Refresh it if the host is ever rebuilt.
- The tunnel authenticates with the same ansible SSH key the rest of the config uses.

### Server-side expectations

The Caddy host must run Caddy with the admin API enabled **and must not let a config file overwrite API-applied changes on restart**. The pattern used by the companion Ansible playbook:

- A minimal Caddyfile that only sets the admin listener (no sites).
- A systemd override so Caddy starts with `--resume`, preferring its autosaved JSON config (written on every API change) over the Caddyfile.
- The Caddyfile is deployed **before** the caddy package is installed, so the package's default Caddyfile (which serves a static page on `:80` as server `srv0`) never runs — otherwise it gets autosaved and permanently collides with the managed `:80` server. If that has already happened, clear it once with:

  ```bash
  curl -sX DELETE http://localhost:2019/config/apps/http/servers/srv0
  ```

---

## Module reference

### `modules/proxmox_node`

Manages VMs (`proxmox_vm_qemu`) and LXC containers (`proxmox_lxc`) on a single Proxmox node. A remote-exec provisioner creates the ansible user on each new host.

| Variable | Type | Description |
|---|---|---|
| `node_name` | `string` | Proxmox node name (e.g. `pve`) |
| `storage` | `string` | Default storage pool (e.g. `local-lvm`) |
| `lxc` | `map(object)` | LXC container definitions (see variables.tf for shape) |
| `machines` | `map(object)` | VM definitions (see variables.tf for shape) |
| `search_domain` | `string` | DNS search domain |
| `dns_nameservers` | `string` | Default DNS nameserver(s); LXCs can override per-container via `nameserver` |
| `ssh_key` | `string` | SSH public key injected into all hosts |
| `ansible_user` | `string` | User created for Ansible access |
| `lxc_password` | `string` | Root password for LXC containers |
| `ssh_private_key_path` | `string` | Private key used by the provisioner to reach new hosts |

| Output | Description |
|---|---|
| `lxc_hosts` | List of `{ name, ip, vmid, filtered_tags }` for each LXC |
| `vm_hosts` | List of `{ name, ip, vmid, filtered_tags }` for each VM |

### `modules/technitium`

Manages DNS zones and records on a Technitium DNS server. Every host in `hosts` gets an A record in the primary zone; manual `records` can override them by name.

| Variable | Type | Description |
|---|---|---|
| `enabled` | `bool` | No-op when false (default) |
| `zone` | `string` | Primary zone, normally the search domain |
| `hosts` | `list(object)` | `{ name, ip }` hosts auto-registered as A records |
| `zones` | `map(object)` | Extra zones: `{ type, forwarder }` |
| `records` | `list(object)` | Manual records: `{ zone, name, type, value, ttl, priority }` |
| `ttl` | `number` | Default TTL (3600) |

### `modules/caddy`

Manages reverse-proxy routes on a Caddy server via its admin API.

| Variable | Type | Description |
|---|---|---|
| `enabled` | `bool` | No-op when false (default) |
| `proxies` | `map(object)` | `{ host, upstreams, protocol, path }` per site |
| `http_listen` | `list(string)` | Listen addresses for the HTTP server (`[":80"]`) |
| `https_listen` | `list(string)` | Listen addresses for the HTTPS server (`[":443"]`) |

### `modules/phpipam`

Registers all declared host addresses in phpIPAM.

| Variable | Type | Description |
|---|---|---|
| `enabled` | `bool` | No-op when false (default) |
| `hosts` | `list(object)` | `{ name, ip }` hosts to register |
| `network_subnets` | `map(string)` | Named CIDR ranges managed by phpIPAM |
