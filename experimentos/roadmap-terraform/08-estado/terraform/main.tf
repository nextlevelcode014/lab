data "aws_caller_identity" "atual" {}

resource "aws_s3_bucket" "app" {
  bucket_prefix = "lab-roadmap-08-app-"
  tags          = { descricao = var.descricao }
}

# Um usuário com chave de acesso: a secret da chave é o segredo que vai parar
# no state sem ninguém pedir. Ele nasce preso ao lab-boundary (sem o teto, o
# lab-terraform nem consegue criá-lo) e não ganha policy nenhuma.
resource "aws_iam_user" "app" {
  name                 = "roadmap-08-app"
  path                 = "/lab/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.atual.account_id}:policy/lab/lab-boundary"
}

resource "aws_iam_access_key" "app" {
  user = aws_iam_user.app.name
}
