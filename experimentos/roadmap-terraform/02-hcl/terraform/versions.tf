terraform {
  # Versão mínima do binário: quem tiver um Terraform mais velho recebe erro
  # no init, em vez de um comportamento diferente no apply.
  required_version = ">= 1.10"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.114"
    }
  }
}
