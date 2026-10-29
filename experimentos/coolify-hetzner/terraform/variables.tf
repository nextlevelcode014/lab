variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Token de API do projeto lab da Hetzner (leitura e escrita)"
}

# Fora do tfvars de propósito: entra por TF_VAR_tailscale_authkey, só na
# sessão do apply que cria a VPS (README). Uso único: ela fica legível no
# metadata service da VPS, que qualquer container do Coolify alcança.
# Opcional para o resto (plan de VPS que já existe, destroy); quem exige na
# criação é a postcondition do hcloud_server.
variable "tailscale_authkey" {
  type        = string
  sensitive   = true
  default     = null
  description = "Auth key do Tailscale: uso único, efêmera, pré-aprovada, tag:lab"

  validation {
    condition     = var.tailscale_authkey == null || startswith(var.tailscale_authkey, "tskey-auth-")
    error_message = "A auth key começa com tskey-auth- (docs/tailscale.md)."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Chave pública do root (Hetzner) e do usuário lab (cloud-init)"
}

variable "name" {
  type    = string
  default = "lab-coolify-hetzner"
}

# Coolify pede 2 vCPU / 2 GB; o cx23 tem 2 vCPU, 4 GB e 40 GB.
variable "server_type" {
  type    = string
  default = "cx23"
}

variable "location" {
  type    = string
  default = "fsn1"
}

variable "image" {
  type    = string
  default = "ubuntu-26.04"
}

variable "tailnet" {
  type = string
}
