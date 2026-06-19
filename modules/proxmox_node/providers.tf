terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
    phpipam = {
      source  = "lord-kyron/phpipam"
      version = "1.6.2"
    }
  }
}
