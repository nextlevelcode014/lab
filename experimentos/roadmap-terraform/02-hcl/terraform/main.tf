# Um bloco: tipo (resource), rótulos (tipo do recurso e nome local) e um
# corpo entre chaves com argumentos (nome = valor) e blocos aninhados.
resource "proxmox_virtual_environment_vm" "base" {
  name      = "roadmap-02-base"
  vm_id     = 990
  node_name = var.node_name
  pool_id   = "lab"
  # Lista de strings, já em ordem alfabética: o Proxmox ordena as tags.
  tags = ["hcl", "lab", "roadmap"]

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

# Tudo aqui sai da "base" por referência (<tipo>.<nome>.<atributo>): é a
# referência que faz o Terraform criar a base primeiro.
resource "proxmox_virtual_environment_vm" "vizinha" {
  # Interpolação: expressão dentro de uma string.
  name = "${proxmox_virtual_environment_vm.base.name}-vizinha"
  # Expressão sem string em volta: a referência sozinha basta.
  vm_id     = proxmox_virtual_environment_vm.base.vm_id + 1
  node_name = var.node_name
  pool_id   = "lab"
  tags      = concat(proxmox_virtual_environment_vm.base.tags, ["vizinha"])

  # Heredoc: string de várias linhas. O "-" em <<- tira a indentação, e o
  # chomp() a quebra de linha final, que o Proxmox não guardaria.
  description = chomp(<<-EOT
    Vizinha da VM ${proxmox_virtual_environment_vm.base.id}.
    Criada no tópico 2 do roadmap.sh de Terraform.
  EOT
  )

  started         = false
  on_boot         = false
  stop_on_destroy = true

  cpu {
    cores = proxmox_virtual_environment_vm.base.cpu[0].cores
  }

  memory {
    # Blocos aninhados viram listas: [0] é o primeiro (e único) memory.
    dedicated = proxmox_virtual_environment_vm.base.memory[0].dedicated * 2
  }
}
