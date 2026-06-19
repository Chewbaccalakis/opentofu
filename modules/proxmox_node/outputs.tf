output "lxc_hosts" {
  value = [
    for key, val in var.lxc : {
      name          = val.hostname
      ip            = split("/", val.ip)[0]
      vmid          = proxmox_lxc.container[key].vmid
      filtered_tags = [for tag in split(";", val.tags != "" ? format("terraform;%s", val.tags) : "terraform") : tag if tag != "terraform"]
    }
  ]
}

output "vm_hosts" {
  value = [
    for key, val in var.machines : {
      name          = val.hostname
      ip            = val.ip
      vmid          = proxmox_vm_qemu.vm[key].vmid
      filtered_tags = [for tag in split(";", val.tags != "" ? format("terraform;%s", val.tags) : "terraform") : tag if tag != "terraform"]
    }
  ]
}
