terraform {
  # 1.9+: a validação de uma variável pode ler outras variáveis (passo 6).
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
