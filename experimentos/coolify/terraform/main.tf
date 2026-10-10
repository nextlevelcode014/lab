# Coolify pede 2 vCPU / 2 GB no mínimo; com builds, 4 GB e disco folgado.
module "coolify" {
  source = "../../../modules/proxmox-vm"

  name           = "lab-coolify"
  vm_id          = 900
  node_name      = var.node_name
  tags           = ["coolify"]
  cores          = 2
  memory_mb      = 4096
  disk_gb        = 40
  ssh_public_key = var.ssh_public_key
}

# Inventário do Ansible: o plugin cloud.terraform lê este recurso do state.
resource "ansible_host" "coolify" {
  name   = "lab-coolify"
  groups = ["coolify"]
  variables = {
    ansible_host = module.coolify.ipv4
    ansible_user = "lab"
  }
}
