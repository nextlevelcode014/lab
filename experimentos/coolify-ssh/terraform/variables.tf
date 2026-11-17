variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Token de leitura e escrita do projeto lab da Hetzner"
}

variable "ssh_public_key" {
  type        = string
  description = "Chave pública para os usuários root e lab, nunca a chave privada"
}

variable "ssh_source_cidrs" {
  type        = list(string)
  description = "IPs autorizados a entrar por SSH: IPv4 /32 ou IPv6 /128"

  validation {
    condition = length(var.ssh_source_cidrs) > 0 && alltrue([
      for cidr in var.ssh_source_cidrs :
      can(cidrhost(cidr, 0)) && (strcontains(cidr, ":") ? endswith(cidr, "/128") : endswith(cidr, "/32"))
    ])
    error_message = "Informe pelo menos um IP específico, com /32 (IPv4) ou /128 (IPv6)."
  }
}

variable "name" {
  type    = string
  default = "lab-coolify-ssh"

  validation {
    condition     = can(regex("^lab-coolify-ssh(-[a-z0-9-]+)?$", var.name))
    error_message = "O nome deve ser lab-coolify-ssh ou começar com lab-coolify-ssh-."
  }
}

variable "server_type" {
  type    = string
  default = "cx23"
}

variable "location" {
  type    = string
  default = "fsn1"
}
