output "servicos" {
  description = "Valores publicados pelas duas instâncias do módulo."
  value = {
    site = module.site.resumo
    api  = module.api.resumo
  }
}
