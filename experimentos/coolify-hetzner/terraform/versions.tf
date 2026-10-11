terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.52"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}
