variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "lab@pve!terraform=<segredo>"
}

variable "node_name" {
  type    = string
  default = "proxmox"
}

variable "ssh_public_key" {
  type        = string
  description = "Chave pública que o cloud-init põe no usuário lab"
}
