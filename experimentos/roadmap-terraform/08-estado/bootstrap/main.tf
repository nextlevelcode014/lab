# O bucket que guarda o state dos outros dois projetos. Este aqui fica com
# state local: um backend não pode morar num bucket que ele mesmo vai criar.
resource "aws_s3_bucket" "state" {
  bucket_prefix = "lab-roadmap-08-state-"
  # No lab, o destroy apaga junto todas as versões dos states. Em produção,
  # nunca: o histórico é o que deixa voltar um state estragado.
  force_destroy = true
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

output "bucket" {
  value = aws_s3_bucket.state.bucket
}
