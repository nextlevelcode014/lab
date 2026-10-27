locals {
  prefixo = "lab-roadmap-06-${var.ambiente}"
  tags = {
    ambiente = var.ambiente
    dono     = "nextlevelcode"
  }
}

resource "aws_s3_bucket" "b" {
  for_each      = var.buckets
  bucket_prefix = "${local.prefixo}-${each.key}-"
  tags          = merge(local.tags, { descricao = each.value.descricao })
}

resource "aws_s3_bucket_versioning" "b" {
  for_each = { for nome, b in var.buckets : nome => b if b.versionamento }
  bucket   = aws_s3_bucket.b[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

