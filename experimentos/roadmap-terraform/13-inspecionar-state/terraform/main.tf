terraform {
  required_version = ">= 1.4"
}

resource "terraform_data" "ambiente" {
  input = "lab"
}

resource "terraform_data" "aplicacao" {
  input = terraform_data.ambiente.output
}

output "aplicacao_id" {
  value = terraform_data.aplicacao.id
}
