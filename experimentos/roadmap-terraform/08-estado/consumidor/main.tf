# Lê o state do app direto do S3: só os outputs ficam visíveis aqui, mas a
# permissão de leitura que isso exige vale para o arquivo inteiro.
data "terraform_remote_state" "app" {
  backend = "s3"
  config = {
    bucket  = var.bucket_state
    key     = "roadmap-08/app.tfstate"
    region  = "eu-central-1"
    profile = "lab"
  }
}

resource "aws_s3_object" "leia_me" {
  bucket  = data.terraform_remote_state.app.outputs.bucket
  key     = "LEIA-ME.txt"
  content = "Bucket da aplicação. Quem lê é o usuário ${data.terraform_remote_state.app.outputs.usuario}.\n"
}
