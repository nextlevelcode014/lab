terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
  }
}
