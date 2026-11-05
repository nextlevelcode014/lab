terraform {
  required_version = ">= 1.4"
}

resource "terraform_data" "ambiente" {
  input = "temporario"
}

resource "terraform_data" "aplicacao" {
  input = terraform_data.ambiente.output
}
