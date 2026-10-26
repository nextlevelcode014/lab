variable "proxmox_endpoint" {
  type    = string
  default = "https://proxmox.<tailnet>.ts.net:8006"
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
