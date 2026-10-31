resource "aws_s3_bucket" "app" {
  bucket_prefix = "lab-roadmap-09-app-"
  force_destroy = true
}

# Dois objetos para mexer por fora no passo 4: um muda de conteúdo, o outro
# some.
resource "aws_s3_object" "config" {
  bucket       = aws_s3_bucket.app.id
  key          = "config.json"
  content      = jsonencode({ versao = 1 })
  content_type = "application/json"
}

resource "aws_s3_object" "leia_me" {
  bucket       = aws_s3_bucket.app.id
  key          = "LEIA-ME.txt"
  content      = "Criado pelo Terraform do roadmap-09.\n"
  content_type = "text/plain"
}

output "bucket" {
  value = aws_s3_bucket.app.bucket
}
