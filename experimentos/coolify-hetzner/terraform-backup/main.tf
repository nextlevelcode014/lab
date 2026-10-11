# State separado do ../terraform de propósito: o teste é destruir a VPS e
# restaurar numa nova, e os backups têm que sobreviver ao destroy dela.

data "aws_caller_identity" "atual" {}

locals {
  # Nome de bucket é global na AWS; o número da conta o torna único.
  bucket   = "lab-coolify-backup-${data.aws_caller_identity.atual.account_id}"
  boundary = "arn:aws:iam::${data.aws_caller_identity.atual.account_id}:policy/lab/lab-boundary"
}

# Criptografia em repouso (SSE-S3) já é o padrão de todo bucket novo.
resource "aws_s3_bucket" "backup" {
  bucket        = local.bucket
  force_destroy = true # lab: o destroy apaga junto o que houver dentro
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# O Coolify precisa de DeleteObject para a retenção. Com versioning, um
# DeleteObject só esconde o arquivo: a versão antiga fica 7 dias, e a chave
# do Coolify não tem DeleteObjectVersion. Chave vazada não apaga backup.
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "versoes-antigas"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.backup]
}
