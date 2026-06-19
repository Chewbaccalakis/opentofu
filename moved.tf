# State migration: resources moved into the proxmox_node module.
# These blocks tell OpenTofu to rename existing state entries rather than
# destroy and recreate. Safe to remove after the first successful apply.

moved {
  from = phpipam_address.ipam_hv2_lxc
  to   = module.hv2.phpipam_address.lxc
}
moved {
  from = phpipam_address.ipam_hv2_vm
  to   = module.hv2.phpipam_address.vm
}
moved {
  from = proxmox_lxc.hv2_container
  to   = module.hv2.proxmox_lxc.container
}
moved {
  from = proxmox_vm_qemu.hv2-prox-vm
  to   = module.hv2.proxmox_vm_qemu.vm
}

moved {
  from = phpipam_address.ipam_hv3_lxc
  to   = module.hv3.phpipam_address.lxc
}
moved {
  from = phpipam_address.ipam_hv3_vm
  to   = module.hv3.phpipam_address.vm
}
moved {
  from = proxmox_lxc.hv3_container
  to   = module.hv3.proxmox_lxc.container
}
moved {
  from = proxmox_vm_qemu.hv3-prox-vm
  to   = module.hv3.proxmox_vm_qemu.vm
}

moved {
  from = phpipam_address.ipam_hv4_lxc
  to   = module.hv4.phpipam_address.lxc
}
moved {
  from = phpipam_address.ipam_hv4_vm
  to   = module.hv4.phpipam_address.vm
}
moved {
  from = proxmox_lxc.hv4_container
  to   = module.hv4.proxmox_lxc.container
}
moved {
  from = proxmox_vm_qemu.hv4-prox-vm
  to   = module.hv4.proxmox_vm_qemu.vm
}

moved {
  from = phpipam_address.ipam_hv5_lxc
  to   = module.hv5.phpipam_address.lxc
}
moved {
  from = phpipam_address.ipam_hv5_vm
  to   = module.hv5.phpipam_address.vm
}
moved {
  from = proxmox_lxc.hv5_container
  to   = module.hv5.proxmox_lxc.container
}
moved {
  from = proxmox_vm_qemu.hv5-prox-vm
  to   = module.hv5.proxmox_vm_qemu.vm
}
