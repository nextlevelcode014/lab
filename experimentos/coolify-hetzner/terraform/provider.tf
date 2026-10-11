# Token do projeto "lab" na Hetzner (docs/nuvem.md), nunca o da produção:
# o token só enxerga o projeto em que foi criado.
provider "hcloud" {
  token = var.hcloud_token
}

provider "ansible" {}
