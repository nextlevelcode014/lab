module "site" {
  source = "./modules/servico"

  nome     = "site"
  ambiente = "lab"
  porta    = 8080
}

module "api" {
  source = "./modules/servico"

  nome     = "api"
  ambiente = "lab"
  porta    = 3000
}
