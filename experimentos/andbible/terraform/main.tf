variable "proxmox_endpoint" { type = string }
variable "proxmox_api_token" {
  type      = string
  sensitive = true

  validation {
    condition     = startswith(var.proxmox_api_token, "lab@pve!")
    error_message = "Use somente o token lab@pve."
  }
}
variable "node_name" {
  type    = string
  default = "proxmox"
}
variable "ssh_public_key" { type = string }

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}

resource "proxmox_virtual_environment_container" "andbible" {
  node_name     = var.node_name
  vm_id         = 903
  pool_id       = "lab"
  description   = "WebDAV descartável para o piloto do AndBible"
  unprivileged  = true
  started       = false
  start_on_boot = true
  tags          = ["lab", "andbible"]

  cpu { cores = 1 }
  memory { dedicated = 512 }
  disk {
    datastore_id = "local-lvm"
    size         = 8
  }
  operating_system {
    template_file_id = "local:vztmpl/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
    type             = "ubuntu"
  }
  network_interface {
    name   = "eth0"
    bridge = "vmbr2"
  }
  initialization {
    hostname = "lab-andbible"
    ip_config {
      ipv4 {
        address = "10.60.0.103/24"
        gateway = "10.60.0.1"
      }
    }
    dns { servers = ["9.9.9.9", "1.1.1.1"] }
    user_account { keys = [var.ssh_public_key] }
  }
  lifecycle {
    # O root@pam configura nesting e o TUN antes do primeiro boot.
    ignore_changes = [features, device_passthrough, started]
  }
}

resource "ansible_host" "andbible" {
  name       = "lab-andbible"
  groups     = ["andbible"]
  depends_on = [proxmox_virtual_environment_container.andbible]
  variables = {
    ansible_host                 = "10.60.0.103"
    ansible_user                 = "root"
    ansible_ssh_private_key_file = "~/.ssh/lab.pub"
    lxc_vmid                     = 903
  }
}
