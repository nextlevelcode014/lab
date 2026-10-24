# Uma VM vazia e desligada: sem disco, sem rede, sem sistema. O tópico 1 não
# é sobre VM, é sobre o ciclo da IaC — descrever o que se quer, ver o plano,
# aplicar, mudar o código e ver só a diferença ser aplicada. Sem disco nem
# boot, criar e destruir leva segundos e não ocupa nada.
resource "proxmox_virtual_environment_vm" "primeira" {
  name      = "roadmap-01"
  vm_id     = 990
  node_name = var.node_name
  pool_id   = "lab"
  tags      = ["lab", "roadmap"]

  description = "Tópico 1 do roadmap.sh de Terraform"

  started         = false
  on_boot         = false
  stop_on_destroy = true

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }
}
