# O bucket do state, agora com as proteções que o 08 deixou de fora. Ele
# mesmo fica com state local: um backend não pode morar no bucket que cria.
resource "aws_s3_bucket" "state" {
  bucket_prefix = "lab-roadmap-09-state-"

  # As duas travas contra apagar, num destroy, o histórico de todos os
  # states. Para destruir no fim do exercício, desligue as duas e aplique
  # antes (README, "Destruir").
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# O state tem segredo em claro: nenhuma ACL ou policy pode torná-lo público.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifra em repouso com chave do próprio S3 (SSE-S3), de graça. Uma chave KMS
# sua exigiria kms:Decrypt de quem lê, mas custa por mês.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Recusa qualquer acesso sem TLS, de quem quer que seja: o state viaja com
# segredo dentro.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "SoComTLS"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  # Com o bloqueio ainda sendo aplicado, a AWS pode recusar a policy.
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# Cada apply guarda uma versão nova do state, para sempre. Mantém as 10
# versões antigas mais recentes; das outras, apaga as que passaram de 90 dias.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "versoes-antigas-do-state"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

output "bucket" {
  value = aws_s3_bucket.state.bucket
}

# A parte do backend que muda por ambiente, pronta para virar o arquivo
# lab.s3.tfbackend do app.
output "backend_config" {
  value = <<-EOT
    bucket  = "${aws_s3_bucket.state.bucket}"
    region  = "eu-central-1"
    profile = "lab"
  EOT
}
