variable "proxmox_endpoint" {
  type = string
}

# Token do lab@pve (docs/proxmox.md), nunca o terraform@pve da produção.
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}

provider "ansible" {}
