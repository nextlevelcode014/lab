variable "name" {
  type        = string
  description = "Nome da VM no Proxmox (e hostname)"
}

variable "vm_id" {
  type        = number
  description = "VMID; o lab usa só 900-999, longe da faixa 200-299 da produção"

  validation {
    condition     = var.vm_id >= 900 && var.vm_id <= 999
    error_message = "VMID do lab fica em 900-999 (a produção usa 200-299)."
  }
}

variable "node_name" {
  type = string
}

variable "pool_id" {
  type        = string
  default     = "lab"
  description = "Pool onde o token lab@pve tem permissão; fora dele o apply falha"
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "disk_gb" {
  type    = number
  default = 20
}

variable "datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

# Baixada uma vez, à mão, como root (docs/proxmox.md): o download pela API
# exige Sys.Modify na raiz, e o token do lab não pode ter isso.
variable "image_id" {
  type    = string
  default = "local:import/ubuntu-26.04-server-cloudimg-amd64.qcow2"
}

# Instala o qemu-guest-agent no primeiro boot: é por ele que o Proxmox (e o
# Terraform) descobre o IP que o DHCP deu. Também criado à mão uma vez.
variable "vendor_data_file_id" {
  type    = string
  default = "local:snippets/lab-vendor.yaml"
}

variable "username" {
  type        = string
  default     = "lab"
  description = "Usuário do cloud-init, com sudo sem senha"
}

variable "ssh_public_key" {
  type = string
}
