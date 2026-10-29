variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "lab@pve!terraform=<segredo>"
}

variable "node_name" {
  type    = string
  default = "proxmox"
}
