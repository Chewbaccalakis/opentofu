terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112"
    }
    # Butane -> Ignition transpiler, used for Flatcar VMs.
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.14"
    }
  }
}
