terraform {
  # 1.11: use_lockfile (trava no próprio S3, sem DynamoDB) deixou de ser experimental.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # O que é igual em todo ambiente fica aqui. Bucket, região e profile mudam
  # de ambiente para ambiente e vêm do arquivo lab.s3.tfbackend, no init.
  backend "s3" {
    key          = "roadmap-09/app.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
