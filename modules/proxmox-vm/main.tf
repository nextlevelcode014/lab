# VM descartável do lab: imagem cloud do Ubuntu importada direto no disco,
# na vmbr2 (a bridge isolada do lab, ADR 0021 do repo infra) com IP fixo
# tirado do VMID, e cloud-init com o usuário e a chave SSH. Uma VM por
# chamada.
locals {
  # Mesma faixa do defaults do role proxmox_host, no repo infra: mudar aqui
  # é mudar lá. VMID 900-999 vira 10.60.0.100-199.
  ipv4    = "10.60.0.${var.vm_id - 800}"
  gateway = "10.60.0.1"
  # Na vmbr2 não há DNS de roteador. Quad9, como os LXCs da produção; a VM
  # que entra na tailnet passa a usar o MagicDNS.
  dns_servers = ["9.9.9.9", "149.112.112.112"]
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  vm_id     = var.vm_id
  node_name = var.node_name
  pool_id   = var.pool_id
  tags      = distinct(concat(["lab"], var.tags))

  on_boot         = false
  stop_on_destroy = true

  # O IP é fixo; esperar o agente no apply é o sinal de que o cloud-init
  # instalou os pacotes (pelo NAT da vmbr2) e a VM está de pé.
  agent {
    enabled = true
    # O agente só sobe depois do cloud-init instalar o pacote.
    timeout = "15m"
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_mb
  }

  operating_system {
    type = "l26"
  }

  # Imagem cloud do Ubuntu espera console serial.
  serial_device {}

  disk {
    datastore_id = var.datastore_id
    import_from  = var.image_id
    interface    = "virtio0"
    size         = var.disk_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = var.bridge
  }

  initialization {
    datastore_id        = var.datastore_id
    vendor_data_file_id = var.vendor_data_file_id

    ip_config {
      ipv4 {
        address = "${local.ipv4}/24"
        gateway = local.gateway
      }
    }

    dns {
      servers = local.dns_servers
    }

    user_account {
      username = var.username
      keys     = [trimspace(var.ssh_public_key)]
    }
  }
}
