# Exclusivamente o token do projeto lab, que não alcança a produção.
provider "hcloud" {
  token = var.hcloud_token
}

provider "ansible" {}
