terraform {
  # 1.11: use_lockfile (trava no próprio S3, sem DynamoDB) deixou de ser experimental.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # O bucket vem no init: -backend-config="bucket=...". Um bloco backend não
  # aceita variável, porque é lido antes de qualquer variável existir.
  backend "s3" {
    key          = "roadmap-08/consumidor.tfstate"
    region       = "eu-central-1"
    profile      = "lab"
    use_lockfile = true
  }
}
