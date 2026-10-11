# Usuário lab-terraform (bootstrap/aws.sh), nunca o "terraform" de fora do
# lab: ele só mexe em buckets lab-* e em usuários /lab/ presos ao lab-boundary.
provider "aws" {
  profile = var.aws_profile
  region  = var.region

  default_tags {
    tags = {
      env         = "lab"
      experimento = "coolify-hetzner"
    }
  }
}
