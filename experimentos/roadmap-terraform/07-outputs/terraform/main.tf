resource "aws_s3_bucket" "b" {
  for_each      = var.buckets
  bucket_prefix = "lab-roadmap-07-${each.key}-"
  tags          = { descricao = each.value.descricao }
}

resource "aws_s3_bucket_versioning" "b" {
  for_each = { for nome, b in var.buckets : nome => b if b.versionamento }
  bucket   = aws_s3_bucket.b[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}
