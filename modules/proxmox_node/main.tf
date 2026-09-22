locals {
  # Tags are declared as a ";"-separated string (tfvars) but the provider wants
  # a list. Proxmox stores tags sorted, so sort here to keep plans clean.
  lxc_tags = { for k, v in var.lxc : k => sort(compact(concat(["terraform"], split(";", v.tags)))) }
  vm_tags  = { for k, v in var.machines : k => sort(compact(concat(["terraform"], split(";", v.tags)))) }

  dns_servers = compact(split(" ", var.dns_nameservers))
}

resource "proxmox_virtual_environment_container" "container" {
  for_each = var.lxc

  node_name     = var.node_name
  vm_id         = each.value.vmid
  unprivileged  = each.value.unprivileged
  start_on_boot = each.value.onboot
  started       = true
  tags          = local.lxc_tags[each.key]

  operating_system {
    template_file_id = each.value.template
    type             = each.value.os_type
  }

  # Proxmox reports an unset core limit as 1 and no cpuunits as 1024; declare
  # both so the provider never rewrites them (changing architecture also needs
  # root@pam, which the API token is not).
  cpu {
    architecture = "amd64"
    cores        = each.value.cores
    units        = 1024
  }

  memory {
    dedicated = each.value.memory
    swap      = each.value.swap
  }

  disk {
    datastore_id = var.storage
    size         = tonumber(trimsuffix(each.value.disk_size, "G"))
  }

  features {
    nesting = true
  }

  initialization {
    hostname = each.value.hostname

    dns {
      domain  = var.search_domain
      servers = each.value.nameserver != null ? compact(split(" ", each.value.nameserver)) : local.dns_servers
    }

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = each.value.gw
      }
    }

    # Must stay positionally aligned with the network_interface blocks below
    # (ip_config index N configures netN).
    dynamic "ip_config" {
      for_each = each.value.nic2 != null ? [each.value.nic2] : []
      content {
        ipv4 {
          address = ip_config.value.ip
          gateway = ip_config.value.gw
        }
      }
    }

    user_account {
      keys     = [trimspace(var.ssh_key)]
      password = var.lxc_password
    }
  }

  network_interface {
    name    = each.value.nic_name
    bridge  = each.value.bridge
    vlan_id = each.value.vlan
  }

  dynamic "network_interface" {
    for_each = each.value.nic2 != null ? [each.value.nic2] : []
    content {
      name    = network_interface.value.nic_name
      bridge  = network_interface.value.bridge
      vlan_id = network_interface.value.vlan
    }
  }

  lifecycle {
    ignore_changes = [
      # Don't fight manual starts/stops (same as the old `start` handling).
      started,
      # Only used at creation time and not readable back from Proxmox; any
      # change here would otherwise force a rebuild of the container.
      operating_system[0].template_file_id,
      initialization[0].user_account,
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = split("/", each.value.ip)[0]
      user        = "root"
      private_key = file(var.ssh_private_key_path)
    }

    inline = [
      "apt-get update -qq && apt-get install -y sudo",
      "useradd -m -s /bin/bash ${var.ansible_user}",
      "echo '${var.ansible_user} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${var.ansible_user}",
      "chmod 440 /etc/sudoers.d/${var.ansible_user}",
      "mkdir -p /home/${var.ansible_user}/.ssh",
      "echo '${var.ssh_key}' >> /home/${var.ansible_user}/.ssh/authorized_keys",
      "chmod 700 /home/${var.ansible_user}/.ssh",
      "chmod 600 /home/${var.ansible_user}/.ssh/authorized_keys",
      "chown -R ${var.ansible_user}:${var.ansible_user} /home/${var.ansible_user}/.ssh",
    ]
  }
}

# VMs are cloned from a template referenced by name in tfvars; resolve the
# name to its VM ID on this node. Fails the plan if the name is ambiguous or
# missing.
data "proxmox_virtual_environment_vms" "template" {
  for_each = toset([for m in var.machines : m.template])

  node_name = var.node_name

  filter {
    name   = "template"
    values = [true]
  }

  filter {
    name   = "name"
    values = [each.key]
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.machines

  node_name = var.node_name
  name      = each.value.hostname
  vm_id     = each.value.vmid
  tags      = local.vm_tags[each.key]
  on_boot   = each.value.onboot
  started   = true

  clone {
    vm_id = one(data.proxmox_virtual_environment_vms.template[each.value.template].vms).vm_id
    full  = each.value.full_clone
  }

  # Options
  bios          = each.value.bios
  machine       = each.value.machine
  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["virtio0"]

  agent {
    enabled = each.value.agent == 1
  }

  # CPU
  cpu {
    type       = each.value.cpu_type
    cores      = each.value.cores
    sockets    = each.value.sockets
    hotplugged = each.value.vcpus
  }

  # Hardware
  memory {
    dedicated = each.value.memory
    floating  = each.value.balloon
  }

  # UEFI vars disk; raw is the format on block storage (local-lvm / zfs).
  dynamic "efi_disk" {
    for_each = each.value.bios == "ovmf" ? [1] : []
    content {
      datastore_id = var.storage
      file_format  = "raw"
      type         = "4m"
    }
  }

  disk {
    interface    = "virtio0"
    datastore_id = var.storage
    size         = tonumber(each.value.disk_size)
    file_format  = "raw"
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    replicate    = false
  }

  network_device {
    bridge  = each.value.bridge
    model   = "virtio"
    vlan_id = each.value.vlan != 0 ? each.value.vlan : null
  }

  # Must stay positionally aligned with the ip_config blocks below (netN
  # configured by cloud-init via ip_config index N).
  dynamic "network_device" {
    for_each = each.value.nic2 != null ? [each.value.nic2] : []
    content {
      bridge  = network_device.value.bridge
      model   = "virtio"
      vlan_id = network_device.value.vlan
    }
  }

  serial_device {
    device = "socket"
  }

  operating_system {
    type = "l26"
  }

  # Cloud-Init
  initialization {
    datastore_id = var.storage
    interface    = "ide2"
    upgrade      = each.value.ciupgrade

    dns {
      domain  = var.search_domain
      servers = local.dns_servers
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = cidrhost(format("%s/24", each.value.ip), 1)
      }
    }

    dynamic "ip_config" {
      for_each = each.value.nic2 != null ? [each.value.nic2] : []
      content {
        ipv4 {
          address = "${ip_config.value.ip}/24"
          gateway = ip_config.value.gw
        }
      }
    }

    user_account {
      username = var.ansible_user
      keys     = [trimspace(var.ssh_key)]
    }
  }

  lifecycle {
    ignore_changes = [
      # Don't fight manual starts/stops.
      started,
      # Clone source is only used at creation time and is not readable back
      # from Proxmox; a change here would otherwise force a rebuild of the VM.
      clone,
    ]
  }
}
