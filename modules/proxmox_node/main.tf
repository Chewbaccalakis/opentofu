resource "proxmox_lxc" "container" {
  for_each = var.lxc

  target_node     = var.node_name
  hostname        = each.value.hostname
  ostemplate      = each.value.template
  vmid            = each.value.vmid
  unprivileged    = each.value.unprivileged
  onboot          = each.value.onboot
  tags            = each.value.tags != "" ? format("terraform;%s", each.value.tags) : "terraform"
  password        = var.lxc_password
  ssh_public_keys = var.ssh_key
  memory          = each.value.memory

  features {
    nesting = true
  }

  rootfs {
    storage = var.storage
    size    = each.value.disk_size
  }

  searchdomain = var.search_domain
  nameserver   = var.dns_nameservers

  network {
    name   = each.value.nic_name
    bridge = each.value.bridge
    ip     = each.value.ip
    gw     = each.value.gw
  }

  lifecycle {
    ignore_changes = [start]
  }
}

resource "proxmox_vm_qemu" "vm" {
  for_each = var.machines

  target_node = var.node_name
  name        = each.value.hostname
  vmid        = each.value.vmid
  clone       = each.value.template
  full_clone  = each.value.full_clone
  tags        = each.value.tags != "" ? format("terraform;%s", each.value.tags) : "terraform"

  # Cloud-Init
  os_type      = "cloud-init"
  ciupgrade    = each.value.ciupgrade
  ipconfig0    = "ip=${each.value.ip}/24,gw=${cidrhost(format("%s/24", each.value.ip), 1)}"
  ipconfig1    = each.value.ip2 != null ? "ip=${each.value.ip2}/24" : null
  searchdomain = var.search_domain
  nameserver   = var.dns_nameservers
  skip_ipv6    = true
  ciuser       = var.ansible_user
  sshkeys      = var.ssh_key

  # Options
  onboot = each.value.onboot
  boot   = "order=virtio0"
  agent  = each.value.agent

  # CPU
  cpu {
    type    = each.value.cpu_type
    cores   = each.value.cores
    vcores  = each.value.vcpus
    sockets = each.value.sockets
  }

  # Hardware
  memory  = each.value.memory
  balloon = each.value.balloon
  bios    = each.value.bios
  machine = each.value.machine
  scsihw  = "virtio-scsi-pci"

  serial {
    id = 0
  }

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = var.storage
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          size     = each.value.disk_size
          cache    = "writeback"
          storage  = var.storage
          iothread = true
          discard  = true
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = each.value.bridge
    tag    = each.value.vlan != 0 ? each.value.vlan : null
  }

  lifecycle {
    ignore_changes = [network]
  }
}
