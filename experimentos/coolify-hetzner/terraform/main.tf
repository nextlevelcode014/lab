# Sem chave SSH no projeto, a Hetzner cria o servidor com senha de root
# (e manda por e-mail). Com ela, o root só entra por chave.
resource "hcloud_ssh_key" "lab" {
  name       = var.name
  public_key = trimspace(var.ssh_public_key)

  labels = {
    env = "lab"
  }
}

resource "hcloud_server" "coolify" {
  name        = var.name
  server_type = var.server_type
  location    = var.location
  image       = var.image
  ssh_keys    = [hcloud_ssh_key.lab.id]

  # Pelo firewall_ids, e não por hcloud_firewall_attachment: o servidor já
  # nasce fechado, sem uma janela com a 22 aberta.
  firewall_ids = [hcloud_firewall.coolify.id]

  # O provider guarda no state só o hash do user_data, não a auth key.
  user_data = var.tailscale_authkey == null ? null : templatefile(
    "${path.module}/cloud-init.yaml.tftpl", {
      hostname          = var.name
      ssh_public_key    = trimspace(var.ssh_public_key)
      tailscale_authkey = var.tailscale_authkey
  })

  labels = {
    env = "lab"
  }

  lifecycle {
    # A auth key é de uso único: a do próximo apply será outra, e isso não
    # pode recriar a VPS. Para refazer o primeiro boot, -replace.
    ignore_changes = [user_data]

    # Sem user_data a VPS nasceria sem Tailscale, e sem 22 pública não
    # haveria como entrar. Numa VPS que já existe vale o do state.
    postcondition {
      condition     = self.user_data != null
      error_message = "Criar a VPS exige a auth key: export TF_VAR_tailscale_authkey (README)."
    }
  }
}

# Inventário do Ansible: o plugin cloud.terraform lê este recurso do state.
# O endereço é o da tailnet: a 22 pública não existe.
resource "ansible_host" "coolify" {
  name   = var.name
  groups = ["coolify"]
  variables = {
    ansible_host = "${var.name}.${var.tailnet}"
    ansible_user = "lab"
  }
}
