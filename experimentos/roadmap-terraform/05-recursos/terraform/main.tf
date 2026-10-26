resource "proxmox_virtual_environment_vm" "base" {
  name      = "roadmap-05"
  vm_id     = 990
  node_name = var.node_name
  pool_id   = "lab"
  tags      = ["lab", "roadmap"]

  started         = false
  on_boot         = false
  stop_on_destroy = true

  purge_on_destroy = false

  depends_on = [aws_s3_bucket.c]

  lifecycle {
    # As Notes são editadas à mão na interface do Proxmox (passo 5).
    ignore_changes       = [description]
    replace_triggered_by = [terraform_data.versao]
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }
}

resource "terraform_data" "versao" {
  input = "2"
}

