output "nomes" {
  description = "Nome real de cada bucket, pela chave do mapa"
  value       = { for chave, b in aws_s3_bucket.b : chave => b.bucket }
}

output "arn_dados" {
  value = aws_s3_bucket.b["dados"].arn
}

output "chave_api" {
  value     = var.chave_api
  sensitive = true
}

output "tamanho_chave" {
  value = nonsensitive(length(var.chave_api))
}

output "bucket_backup" {
  value      = aws_s3_bucket.b[var.backup].bucket
  depends_on = [aws_s3_bucket_versioning.b]

  precondition {
    condition     = contains(keys(var.buckets), var.backup)
    error_message = "backup = \"${var.backup}\" não é chave de var.buckets."
  }

  precondition {
    condition     = var.buckets[var.backup].versionamento
    error_message = "O bucket de backup precisa de versionamento = true."
  }
}
