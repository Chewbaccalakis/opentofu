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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.2"
    }
  }
}

data "external" "infisical" {
  program = ["bash", "-c", "infisical export --template=./secrets.tmpl"]
}

provider "proxmox" {
  alias               = "hv2"
  pm_api_url          = var.hypervisors["hv2"].api_url
  pm_api_token_id     = data.external.infisical.result["token_id"]
  pm_api_token_secret = data.external.infisical.result["hv2_token_secret"]
  pm_tls_insecure     = true
}

provider "proxmox" {
  alias               = "hv3"
  pm_api_url          = var.hypervisors["hv3"].api_url
  pm_api_token_id     = data.external.infisical.result["token_id"]
  pm_api_token_secret = data.external.infisical.result["hv3_token_secret"]
  pm_tls_insecure     = true
}

provider "proxmox" {
  alias               = "hv4"
  pm_api_url          = var.hypervisors["hv4"].api_url
  pm_api_token_id     = data.external.infisical.result["token_id"]
  pm_api_token_secret = data.external.infisical.result["hv4_token_secret"]
  pm_tls_insecure     = true
}

provider "proxmox" {
  alias               = "hv5"
  pm_api_url          = var.hypervisors["hv5"].api_url
  pm_api_token_id     = data.external.infisical.result["token_id"]
  pm_api_token_secret = data.external.infisical.result["hv5_token_secret"]
  pm_tls_insecure     = true
}

provider "phpipam" {
  app_id             = "tofu"
  endpoint           = var.ipam_endpoint
  username           = try(data.external.infisical.result["ipam_username"], "")
  password           = try(data.external.infisical.result["ipam_password"], "")
  insecure           = false
  nest_custom_fields = false
}
