resource "proxmox_virtual_environment_vm" "base" {
  name      = "roadmap-04"
  vm_id     = 990
  node_name = var.node_name
  pool_id   = "lab"
  tags      = ["lab", "roadmap"]

  started         = false
  on_boot         = false
  stop_on_destroy = true

  purge_on_destroy = false

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }
}

resource "aws_s3_bucket" "eu" {
  bucket_prefix = "lab-roadmap-04-"
}


