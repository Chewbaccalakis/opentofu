# ── Site configuration ─────────────────────────────────────────────────────────

hypervisors = {
  hv1 = {
    api_url   = "https://192.168.1.10:8006/api2/json"
    node_name = "pve"
    storage   = "local-lvm"
  }
}

ipam_endpoint = "https://ipam.example.com/api"

network_subnets = {
  lan = "192.168.1.0/24"
}

ansible_user    = "ansible"
search_domain   = "example.lan"
dns_nameservers = "1.1.1.1"
technitium_host = "http://192.168.1.2:5380"

# ── DNS (Technitium) ────────────────────────────────────────────────────────────
# Every declared node automatically gets an A record in the search_domain zone.
# Define extra zones and manual records below. The technitium module enables
# itself once TECHNITIUM_API_TOKEN exists in Infisical.

# Additional zones beyond the auto-managed search_domain zone.
dns_zones = {
  # "internal.example.com"    = { type = "Primary" }
  # "1.168.192.in-addr.arpa"  = { type = "Primary" }
}

# Manual records. In the search_domain zone, a record whose name matches an
# auto-added host replaces that host's record instead of conflicting with it.
dns_records = [
  # { zone = "example.lan", name = "router", type = "A",     value = "192.168.1.1" },
  # { zone = "example.lan", name = "nas",    type = "CNAME", value = "storage.example.lan" },
  # { zone = "example.lan", name = "@",      type = "MX",    value = "mail.example.lan", priority = 10 },
]

# ── Reverse proxy (Caddy) ───────────────────────────────────────────────────────
# Managed on the caddy LXC. The admin API listens on loopback, so reach it by
# tunneling SSH to the box as the ansible user. Clear caddy_host to disable
# Caddy management entirely.

caddy_host     = "http://localhost:2019"
caddy_ssh_host = "ansible@192.168.1.5:22"
# From: ssh-keyscan <caddy-ip> — must be refreshed if the LXC is rebuilt.
# Must be the ECDSA key: the provider's (old) Go SSH client prefers
# ecdsa-sha2-nistp256 during negotiation and pins the exact key it receives.
caddy_ssh_host_key = "192.168.1.5 ecdsa-sha2-nistp256 AAAA...replace-me..."

# Each proxy serves plain HTTP on :80 by default; set protocol = "https" to
# serve it on :443 instead. Non-public hostnames (e.g. .lan) can't get public
# certificates, so HTTPS sites use Caddy's internal CA — trust its root cert on
# your devices to avoid browser warnings.
caddy_proxies = {
  # wiki = {
  #   host      = "wiki.example.lan"
  #   upstreams = ["192.168.1.20:8080"]
  # }
  # secure-example = {
  #   host      = "secure.example.lan"
  #   upstreams = ["192.168.1.21:80"]
  #   protocol  = "https"
  # }
}

# ── Node definitions ───────────────────────────────────────────────────────────

nodes = {
  hv1 = {
    lxc = {
      "caddy" = {
        hostname     = "caddy"
        vmid         = 101
        template     = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
        unprivileged = true
        onboot       = true
        tags         = ""
        memory       = 1024
        swap         = 0
        disk_size    = "8G"
        nic_name     = "eth0"
        bridge       = "vmbr0"
        ip           = "192.168.1.5/24"
        nameserver   = "192.168.1.2"
        gw           = "192.168.1.1"
      }
      "technitium" = {
        hostname     = "technitium"
        vmid         = 102
        template     = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
        unprivileged = true
        onboot       = true
        tags         = ""
        memory       = 2048
        swap         = 0
        disk_size    = "8G"
        nic_name     = "eth0"
        bridge       = "vmbr0"
        ip           = "192.168.1.2/24"
        gw           = "192.168.1.1"
      }
    }
    machines = {
      "dev01" = {
        hostname   = "dev01"
        vmid       = 200
        ip         = "192.168.1.50"
        template   = "Debian13"
        full_clone = true
        onboot     = true
        tags       = "dev"
        agent      = 1
        memory     = 4096
        disk_size  = "32"
        balloon    = 1
        cpu_type   = "kvm64"
        cores      = 4
        sockets    = 1
        vcpus      = 0
        bios       = "ovmf"
        machine    = "q35"
        bridge     = "vmbr0"
      }
    }
  }
}
