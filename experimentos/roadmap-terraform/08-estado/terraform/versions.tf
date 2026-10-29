terraform {
  # 1.11: use_lockfile (trava no próprio S3, sem DynamoDB) deixou de ser experimental.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
