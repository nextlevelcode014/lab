variable "ambiente" {
  type        = string
  description = "dev, hml ou prod: entra no nome e nas tags dos buckets"

  validation {
    condition     = contains(["dev", "hml", "prod"], var.ambiente)
    error_message = "ambiente tem que ser dev, hml ou prod."
  }
}

variable "buckets" {
  type = map(object({
    descricao     = string
    versionamento = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for nome in keys(var.buckets) : can(regex("^[a-z0-9]{1,10}$", nome))])
    error_message = "Nome de bucket: só minúsculas e números, até 10 caracteres."
  }

  validation {
    condition     = var.ambiente != "prod" || alltrue([for b in values(var.buckets) : b.versionamento])
    error_message = "Em prod, todo bucket tem versionamento = true."
  }
}
