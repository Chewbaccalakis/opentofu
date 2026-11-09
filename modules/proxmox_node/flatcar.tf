# Flatcar Container Linux VMs.
#
# Flow: download the official Proxmox VE qcow2 image into the node's "import"
# datastore (API, no SSH) -> render Butane to Ignition with poseidon/ct ->
# upload the Ignition JSON as a snippet (needs SSH to the node) -> create the
# VM with the image imported as its boot disk and the snippet as cloud-init
# user-data (Proxmox `cicustom user=`). Flatcar's Ignition reads that user-data
# on first boot; Afterburn applies the IP/DNS Proxmox generates from ip_config.

locals {
  # The upstream file is qcow2-formatted despite its .img name. Proxmox's
  # download-url API validates the destination filename's extension for the
  # "import" content type and rejects .img, so the destination is renamed to
  # .qcow2; the source url is unaffected.
  flatcar_image_file = "flatcar-${var.flatcar_image.channel}-${var.flatcar_image.version}.qcow2"
  flatcar_image_url  = "https://${var.flatcar_image.channel}.release.flatcar-linux.net/amd64-usr/${var.flatcar_image.version}/flatcar_production_proxmoxve_image.img"

  flatcar_tags = { for k, v in var.flatcar : k => sort(compact(concat(["terraform", "flatcar"], split(";", v.tags)))) }

  # Base Butane config: hostname (Afterburn cannot set it because the user-data
  # is Ignition, not cloud-config), the Docker Hub mirror (except on the VM
  # that hosts it) and the ansible user with the shared key.
  flatcar_base_butane = {
    for k, v in var.flatcar : k => yamlencode({
      variant = "flatcar"
      version = "1.0.0"
      storage = {
        files = concat([{
          path     = "/etc/hostname"
          mode     = 420 # 0644
          contents = { inline = v.hostname }
          }],
          var.docker_registry_mirror != null && !strcontains(coalesce(var.docker_registry_mirror, "-"), "//${v.ip}:") ? [{
            path = "/etc/docker/daemon.json"
            mode = 420 # 0644
            contents = { inline = jsonencode({
              "registry-mirrors"    = [var.docker_registry_mirror]
              "insecure-registries" = [regex("//([^/]+)", var.docker_registry_mirror)[0]]
            }) }
        }] : [])
      }
      passwd = {
        users = [
          {
            name                = "core"
            ssh_authorized_keys = [trimspace(var.ssh_key)]
          },
          {
            name                = var.ansible_user
            ssh_authorized_keys = [trimspace(var.ssh_key)]
            groups              = ["sudo", "docker"]
          },
        ]
      }
    })
  }
}

# One image per node, only when the node actually has Flatcar VMs.
resource "proxmox_download_file" "flatcar" {
  count = length(var.flatcar) > 0 ? 1 : 0

  node_name          = var.node_name
  datastore_id       = var.flatcar_image.datastore
  content_type       = "import"
  url                = local.flatcar_image_url
  file_name          = local.flatcar_image_file
  checksum           = var.flatcar_image.sha512
  checksum_algorithm = "sha512"
  upload_timeout     = 1800
}

data "ct_config" "flatcar" {
  for_each = var.flatcar

  strict       = true
  pretty_print = false
  content      = local.flatcar_base_butane[each.key]
  snippets = compact([
    each.value.butane != null ? each.value.butane : "",
    each.value.butane_file != null ? templatefile("${path.root}/${each.value.butane_file}", var.butane_vars) : "",
  ])
}

resource "proxmox_virtual_environment_file" "flatcar_ignition" {
  for_each = var.flatcar

  node_name    = var.node_name
  datastore_id = var.snippets_datastore
  content_type = "snippets"

  source_raw {
    data      = data.ct_config.flatcar[each.key].rendered
    file_name = "${each.value.hostname}-ignition.json"
  }
}

resource "proxmox_virtual_environment_vm" "flatcar" {
  for_each = var.flatcar

  node_name = var.node_name
  name      = each.value.hostname
  vm_id     = each.value.vmid
  tags      = local.flatcar_tags[each.key]
  on_boot   = each.value.onboot
  started   = true

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["virtio0"]

  # Flatcar ships no qemu-guest-agent binary; only enable this alongside a
  # Butane unit that actually runs one in a container (see
  # var.flatcar[*].qemu_guest_agent), otherwise every plan/apply that touches
  # this VM waits out the agent timeout instead of getting a response.
  agent {
    enabled = each.value.qemu_guest_agent
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = each.value.cpu_type
  }

  memory {
    dedicated = each.value.memory
  }

  efi_disk {
    datastore_id = var.storage
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    interface    = "virtio0"
    datastore_id = var.storage
    import_from  = proxmox_download_file.flatcar[0].id
    size         = each.value.disk_size
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge  = each.value.bridge
    model   = "virtio"
    vlan_id = each.value.vlan != 0 ? each.value.vlan : null
  }

  serial_device {
    device = "socket"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id      = var.storage
    interface         = "ide2"
    user_data_file_id = proxmox_virtual_environment_file.flatcar_ignition[each.key].id

    dns {
      domain  = var.search_domain
      servers = local.dns_servers
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = coalesce(each.value.gw, cidrhost(format("%s/24", each.value.ip), 1))
      }
    }
  }

  lifecycle {
    ignore_changes = [
      # Don't fight manual starts/stops.
      started,
      # Only used when the disk is first created; bumping the image version
      # must not touch existing VMs.
      disk[0].import_from,
    ]
  }
}

# Pushes each VM's secret_files to /etc/secrets over SSH as the ansible user,
# so secrets reach the VM from the secret store via tofu without passing
# through Ignition. Re-runs when a value changes (the trigger is a hash; the
# values themselves are already in state through the root module's secret
# data source) and whenever the VM is replaced, since a rebuilt disk starts
# empty.
#
# Provisioners cannot loop, so the files travel as one generated script:
# values are base64-encoded (no quoting to get wrong), uploaded into a 0700
# directory, run under sudo, then deleted. Each file is written then renamed,
# and .pushed last, so a unit waiting on .pushed never sees a partial set.
resource "terraform_data" "flatcar_secrets" {
  for_each = { for k, v in var.flatcar : k => v if length(v.secret_files) > 0 }

  triggers_replace = sha256(jsonencode({
    files = { for name, key in each.value.secret_files : name => var.butane_vars[key] }
    units = each.value.secret_units
  }))

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ansible_user
    private_key = file(var.ssh_private_key_path)
    # First boot (Ignition, then sshd) can take a while after the VM resource
    # reports created.
    timeout = "10m"
  }

  provisioner "remote-exec" {
    inline = ["install -d -m 0700 /home/${var.ansible_user}/.secrets-push"]
  }

  provisioner "file" {
    destination = "/home/${var.ansible_user}/.secrets-push/push.sh"
    content = join("\n", concat(
      ["set -eu", "umask 077", "install -d -m 0700 /etc/secrets"],
      [for name, key in each.value.secret_files :
        "printf '%s' '${base64encode(var.butane_vars[key])}' | base64 -d > '/etc/secrets/.${name}.tmp' && mv -f '/etc/secrets/.${name}.tmp' '/etc/secrets/${name}'"
      ],
      ["touch /etc/secrets/.pushed"],
      [for u in each.value.secret_units : "systemctl try-restart '${u}'"],
      [""],
    ))
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sh /home/${var.ansible_user}/.secrets-push/push.sh; rc=$?; rm -rf /home/${var.ansible_user}/.secrets-push; exit $rc",
    ]
  }

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.flatcar[each.key]]
  }
}
