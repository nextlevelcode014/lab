# O Audiobookshelf é leve (Node + SQLite): 2 GB sobram. O disco é para os
# livros e podcasts de teste, não para o app.
module "audiobookshelf" {
  source = "../../../modules/proxmox-vm"

  name           = "lab-audiobookshelf"
  vm_id          = 901
  node_name      = var.node_name
  tags           = ["audiobookshelf"]
  cores          = 2
  memory_mb      = 2048
  disk_gb        = 30
  ssh_public_key = var.ssh_public_key
}

# Inventário do Ansible: o plugin cloud.terraform lê este recurso do state.
resource "ansible_host" "audiobookshelf" {
  name   = "lab-audiobookshelf"
  groups = ["audiobookshelf"]
  variables = {
    ansible_host = module.audiobookshelf.ipv4
    ansible_user = "lab"
  }
}
