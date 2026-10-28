variable "buckets" {
  type = map(object({
    descricao     = string
    versionamento = optional(bool, false)
  }))
  default = {
    dados = { descricao = "dados da aplicação", versionamento = true }
    logs  = { descricao = "logs de acesso" }
  }
}

variable "chave_api" {
  type      = string
  sensitive = true
  default   = "segredo-de-mentira-123"
}

variable "backup" {
  type        = string
  description = "Chave do bucket que a ferramenta de backup vai ler"
  default     = "dados"
}

