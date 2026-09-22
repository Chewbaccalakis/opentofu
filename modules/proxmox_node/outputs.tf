output "lxc_hosts" {
  value = [
    for key, val in var.lxc : {
      name          = val.hostname
      ip            = split("/", val.ip)[0]
      vmid          = proxmox_virtual_environment_container.container[key].vm_id
      filtered_tags = [for tag in split(";", val.tags != "" ? format("terraform;%s", val.tags) : "terraform") : tag if tag != "terraform"]
    }
  ]
}

output "vm_hosts" {
  value = [
    for key, val in var.machines : {
      name          = val.hostname
      ip            = val.ip
      vmid          = proxmox_virtual_environment_vm.vm[key].vm_id
      filtered_tags = [for tag in split(";", val.tags != "" ? format("terraform;%s", val.tags) : "terraform") : tag if tag != "terraform"]
    }
  ]
}

output "flatcar_hosts" {
  value = [
    for key, val in var.flatcar : {
      name          = val.hostname
      ip            = val.ip
      vmid          = proxmox_virtual_environment_vm.flatcar[key].vm_id
      filtered_tags = [for tag in local.flatcar_tags[key] : tag if tag != "terraform"]
    }
  ]
}
