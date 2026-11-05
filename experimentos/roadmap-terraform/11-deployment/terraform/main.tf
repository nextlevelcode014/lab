terraform {
  required_version = ">= 1.4"
}

variable "release" {
  description = "Versão a registrar no deployment simulado."
  type        = string
  default     = "v1"
}

resource "terraform_data" "deployment" {
  input = var.release
}

output "release_aplicada" {
  description = "Versão registrada no state."
  value       = terraform_data.deployment.output
}
