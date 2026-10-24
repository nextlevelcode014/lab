# VM descartável do lab: imagem cloud do Ubuntu importada direto no disco,
# rede por DHCP (o IP vem do qemu-guest-agent) e cloud-init com o usuário e
# a chave SSH. Uma VM por chamada.
resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  vm_id     = var.vm_id
  node_name = var.node_name
  pool_id   = var.pool_id
  tags      = distinct(concat(["lab"], var.tags))

  on_boot         = false
  stop_on_destroy = true
  # Sem isto, o destroy (com purge) apaga a ACL de /vms/<id> do lab@pve e o
  # próximo create no mesmo VMID falha com 403 (docs/proxmox.md).
  purge_on_destroy = false

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
        address = "dhcp"
      }
    }

    user_account {
      username = var.username
      keys     = [trimspace(var.ssh_public_key)]
    }
  }
}
