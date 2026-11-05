variable "proxmox_endpoint" { type = string }
variable "proxmox_api_token" {
  type      = string
  sensitive = true
  validation {
    condition     = startswith(var.proxmox_api_token, "lab@pve!")
    error_message = "Este ensaio exige token lab@pve; token de produção é recusado."
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
resource "proxmox_virtual_environment_container" "dns_test" {
  node_name    = var.node_name
  vm_id        = 902
  pool_id      = "lab"
  description  = "Ensaio descartável do DNS LXC do PR 69"
  unprivileged = true
  started      = false
  tags         = ["lab", "dns-test"]
  cpu { cores = 2 }
  memory { dedicated = 1024 }
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
    hostname = "lab-dns-pr69"
    ip_config {
      ipv4 {
        address = "10.60.0.102/24"
        gateway = "10.60.0.1"
      }
    }
    dns { servers = ["86.54.11.100", "1.1.1.1"] }
    user_account { keys = [var.ssh_public_key] }
  }
  features {
    nesting = true
    keyctl  = false
  }
  lifecycle {
    ignore_changes = [features[0].keyctl, device_passthrough, started]
  }
}

# A seleção de staging nunca entra nos inventários dos outros experimentos.
resource "ansible_host" "dns_test" {
  name       = "lab-dns-pr69"
  groups     = ["lxc", "staging", "lxc_dns_test"]
  depends_on = [proxmox_virtual_environment_container.dns_test]
  variables = {
    ansible_host                 = "10.60.0.102"
    ansible_user                 = "root"
    ansible_ssh_private_key_file = "~/.ssh/lab.pub"
    lxc_vmid                     = 902
    lxc_dns_tailnet_enabled      = true
  }
}
