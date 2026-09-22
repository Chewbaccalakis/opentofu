terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.2"
    }
    # Butane -> Ignition transpiler for Flatcar VMs (no provider config needed).
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.14"
    }
    technitium = {
      source  = "kenske/technitium"
      version = "~> 0.2"
    }
    caddy = {
      source  = "conradludgate/caddy"
      version = "~> 0.2"
    }
    # phpipam = {
    #   source  = "lord-kyron/phpipam"
    #   version = "1.6.2"
    # }
  }
}

data "external" "infisical" {
  program = ["bash", "-c", "infisical export --template=./secrets.tmpl"]
}

provider "technitium" {
  host = var.technitium_host
  # Fall back to a placeholder so the provider passes its credential check on
  # the first run (before the token exists in Infisical). No technitium
  # resources are created while the token is absent, so the dummy is never used.
  token = coalesce(try(data.external.infisical.result["technitium_api_token"], ""), "token-not-yet-provisioned")
}

provider "caddy" {
  # Endpoint as seen from wherever the request lands: with the SSH tunnel below
  # this is the caddy host's own loopback admin API; without it, a directly
  # reachable admin endpoint. Falls back to the Caddy default so the provider
  # configures cleanly before caddy_host is set (no resources use it until then).
  host = coalesce(var.caddy_host, "http://localhost:2019")

  # Tunnel to the admin API over SSH when it only listens on loopback (the
  # default, recommended setup). Reuses the ansible key generated in main.tf.
  # Leave caddy_ssh_host empty to talk to caddy_host directly.
  dynamic "ssh" {
    for_each = var.caddy_ssh_host != "" ? [1] : []
    content {
      host     = var.caddy_ssh_host
      key_file = local_sensitive_file.ssh_private_key.filename
      host_key = var.caddy_ssh_host_key
    }
  }
}

# Uncomment when phpIPAM is running and credentials are in Infisical.
# provider "phpipam" {
#   app_id             = "tofu"
#   endpoint           = var.ipam_endpoint
#   username           = coalesce(try(data.external.infisical.result["ipam_username"], ""), "user-not-yet-provisioned")
#   password           = coalesce(try(data.external.infisical.result["ipam_password"], ""), "pass-not-yet-provisioned")
#   insecure           = false
#   nest_custom_fields = false
# }

# One provider alias per hypervisor. To add a hypervisor, add a provider block
# here, a module block in main.tf, and its token secret to secrets.tmpl.
provider "proxmox" {
  alias     = "hv1"
  endpoint  = var.hypervisors["hv1"].api_url
  api_token = "${data.external.infisical.result["token_id"]}=${data.external.infisical.result["hv1_token_secret"]}"
  insecure  = true

  # SSH is only used to upload Ignition snippets for Flatcar VMs (Proxmox has
  # no API for snippets). Requires the ansible public key in root's
  # authorized_keys on the node; see flatcar-todo.md.
  ssh {
    username    = "root"
    private_key = base64decode(data.external.infisical.result["ssh_private_key_b64"])

    node {
      name    = var.hypervisors["hv1"].node_name
      address = regex("^https?://([^:/]+)", var.hypervisors["hv1"].api_url)[0]
    }
  }
}
