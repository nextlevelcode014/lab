provider "aws" {
  profile = "lab"
  region  = "eu-central-1"
  default_tags {
    tags = {
      env         = "lab"
      experimento = "roadmap-09-app"
    }
  }
}
