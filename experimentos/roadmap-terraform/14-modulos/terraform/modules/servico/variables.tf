variable "nome" {
  description = "Nome do serviço representado no state local."
  type        = string

  validation {
    condition     = length(trimspace(var.nome)) > 0
    error_message = "O nome não pode ficar vazio."
  }
}

variable "ambiente" {
  description = "Ambiente usado na identificação do serviço."
  type        = string

  validation {
    condition     = var.ambiente == "lab"
    error_message = "Este exercício aceita apenas o ambiente lab."
  }
}

variable "porta" {
  description = "Porta ilustrativa; nenhum processo ou socket será aberto."
  type        = number
  default     = 8080

  validation {
    condition     = var.porta >= 1 && var.porta <= 65535 && floor(var.porta) == var.porta
    error_message = "A porta deve ser um inteiro entre 1 e 65535."
  }
}
