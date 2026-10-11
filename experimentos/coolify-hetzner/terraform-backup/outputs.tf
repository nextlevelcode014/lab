# O que vai em Coolify → S3 Storages → + Add.
output "bucket" {
  value = aws_s3_bucket.backup.id
}

output "region" {
  value = var.region
}

output "endpoint" {
  value = "https://s3.${var.region}.amazonaws.com"
}

output "access_key" {
  value = aws_iam_access_key.coolify.id
}

output "secret_key" {
  value     = aws_iam_access_key.coolify.secret
  sensitive = true
}
