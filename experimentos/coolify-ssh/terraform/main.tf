# Sem bloco backend: state local e próprio deste experimento.
locals {
  labels = {
    env         = "lab"
    experimento = "coolify-ssh"
  }
}

resource "hcloud_ssh_key" "lab" {
  name       = var.name
  public_key = trimspace(var.ssh_public_key)
  labels     = local.labels
}

resource "hcloud_server" "coolify" {
  name         = var.name
  server_type  = var.server_type
  location     = var.location
  image        = "ubuntu-24.04"
  ssh_keys     = [hcloud_ssh_key.lab.id]
  firewall_ids = [hcloud_firewall.coolify.id]
  labels       = local.labels

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname       = var.name
    ssh_public_key = trimspace(var.ssh_public_key)
  })
}

resource "ansible_host" "coolify" {
  name   = var.name
  groups = ["coolify"]
  variables = {
    ansible_host    = hcloud_server.coolify.ipv4_address
    ansible_user    = "lab"
    lab_experimento = "coolify-ssh"
  }
}
