resource "terraform_data" "servico" {
  input = {
    nome     = "${var.ambiente}-${var.nome}"
    ambiente = var.ambiente
    porta    = var.porta
  }
}
