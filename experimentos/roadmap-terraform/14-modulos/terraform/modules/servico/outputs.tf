output "resumo" {
  description = "Contrato público do serviço: identificação e configuração registrada."
  value = {
    id           = terraform_data.servico.id
    configuracao = terraform_data.servico.output
  }
}
