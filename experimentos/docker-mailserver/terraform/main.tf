module "docker_mailserver" {
  source = "../../../modules/proxmox-vm"

  name           = "lab-docker-mailserver"
  vm_id          = 903
  node_name      = var.node_name
  tags           = ["docker-mailserver"]
  ssh_public_key = var.ssh_public_key
}

resource "ansible_host" "docker_mailserver" {
  name   = "lab-docker-mailserver"
  groups = ["docker_mailserver"]
  variables = {
    ansible_host = module.docker_mailserver.ipv4
    ansible_user = "lab"
  }
}

output "ip" {
  value = module.docker_mailserver.ipv4
}
