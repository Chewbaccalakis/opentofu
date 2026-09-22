variable "node_name" {
  type = string
}

# "local-lvm" for HV2/3/4, "local-zfs" for HV5
variable "storage" {
  type = string
}

variable "lxc" {
  type = map(object({
    hostname     = string
    vmid         = number
    template     = string
    os_type      = optional(string, "debian")
    unprivileged = bool
    onboot       = bool
    tags         = string
    cores        = optional(number, 1)
    memory       = number
    swap         = number
    disk_size    = string
    nic_name     = string
    bridge       = string
    vlan         = optional(number)
    ip           = string
    nameserver   = optional(string)
    gw           = string
    # Optional second NIC, e.g. for a separate VLAN/subnet. `ip` is a full
    # CIDR address (matches the primary `ip` field's format).
    nic2 = optional(object({
      nic_name = optional(string, "eth1")
      bridge   = optional(string, "vmbr0")
      vlan     = optional(number)
      ip       = string
      gw       = optional(string)
    }))
  }))
  default = {}
}

variable "machines" {
  type = map(object({
    hostname   = string
    vmid       = number
    ip         = string
    vlan       = optional(number, 0)
    template   = string
    full_clone = bool
    onboot     = bool
    ciupgrade  = optional(bool, false)
    tags       = string
    agent      = number
    memory     = number
    disk_size  = optional(string, "32")
    balloon    = number
    cpu_type   = string
    cores      = number
    sockets    = number
    vcpus      = number
    bios       = string
    machine    = string
    bridge     = string
    # Optional second NIC, e.g. for a separate VLAN/subnet. `ip` is bare
    # (matches the primary `ip` field's format), assumed /24; gateway is only
    # configured if given, since the default route already comes from the
    # primary NIC.
    nic2 = optional(object({
      bridge = optional(string, "vmbr0")
      vlan   = optional(number)
      ip     = string
      gw     = optional(string)
    }))
  }))
  default = {}
}

variable "search_domain" {
  type = string
}

variable "dns_nameservers" {
  type = string
}

variable "ssh_key" {
  type = string
}

variable "ansible_user" {
  type = string
}

variable "lxc_password" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_path" {
  type = string
}

# Flatcar Container Linux VMs. These are built from the official Proxmox VE
# image (not cloned from a template) and provisioned with Ignition, so there is
# no cloud-init user account and no remote-exec provisioner. Flatcar itself
# ships no qemu-guest-agent binary (no package manager); see
# qemu_guest_agent below for a best-effort containerized workaround.
# Static IP/DNS still come from the cloud-init drive (Afterburn applies them);
# hostname and SSH keys are set through Ignition.
variable "flatcar" {
  type = map(object({
    hostname  = string
    vmid      = number
    ip        = string # bare IPv4, assumed /24 with gateway .1 (same as machines)
    gw        = optional(string)
    vlan      = optional(number, 0)
    bridge    = optional(string, "vmbr0")
    onboot    = optional(bool, true)
    tags      = optional(string, "")
    cores     = optional(number, 2)
    cpu_type  = optional(string, "x86-64-v2-AES")
    memory    = optional(number, 4096)
    disk_size = optional(number, 32) # GB
    # Adds the virtio-serial channel Proxmox's guest agent integration needs
    # (qm agent, IP display in the UI, graceful shutdown). Flatcar has no
    # native qemu-guest-agent; pair this with a Butane unit that runs one in a
    # privileged container (see butane/example-qga.yaml). Until that unit is
    # actually running, plans/applies that touch this VM will wait out the
    # agent timeout instead of getting a response.
    qemu_guest_agent = optional(bool, false)
    # Extra Butane YAML (variant: flatcar, version: 1.0.0) merged into the
    # generated base config: inline (butane) and/or a file path relative to
    # the root module (butane_file). Only applied at first boot: to re-apply,
    # taint the VM (which rebuilds it from the image).
    butane      = optional(string)
    butane_file = optional(string)
  }))
  default = {}
}

# Which Flatcar release to import. Pin a version (not "current") so the image
# file on the node does not silently change. sha512 comes from
# https://<channel>.release.flatcar-linux.net/amd64-usr/<version>/flatcar_production_proxmoxve_image.img.DIGESTS
variable "flatcar_image" {
  type = object({
    channel   = optional(string, "stable")
    version   = string
    sha512    = string
    datastore = optional(string, "local") # must have the "import" content type enabled
  })
  default = {
    version = "4593.2.5"
    sha512  = "21fdba07ffc73aac80aa40f1f99e0460e2d53b1c2815a774d5e2940d2b5cfa78fb2c86391fbf3bb76e28e8ece1ca41333f30ce18d1dd3f0c016e95bed120aba8"
  }
}

# Datastore that holds the Ignition snippets. Must have the "snippets" content
# type enabled, and the provider needs SSH access to the node to upload them.
variable "snippets_datastore" {
  type    = string
  default = "local"
}

# Values available to every butane_file, which is rendered with templatefile().
# This is how secrets reach a Butane config without being committed: the root
# module passes its secret store's output here and the file refers to a key as
# ${key_name}. Butane files are templates whether or not they use this, so a
# literal ${...} in one (a shell variable, say) must be escaped as $${...}.
variable "butane_vars" {
  type    = map(string)
  default = {}
}
