# AWS e Google Cloud

Esquecer uma instância ligada é o erro mais caro deste repo. Antes do
**primeiro** `terraform apply` numa nuvem:

## 1. Conta ou projeto só do lab

- **AWS:** uma conta separada (AWS Organizations) ou, no mínimo, um usuário
  IAM só do lab.
- **Google:** um projeto `nlc-lab`, só para isto.

Assim apagar tudo é apagar a conta ou o projeto, e o custo fica isolado.

## 2. Alerta de custo (no navegador)

- **AWS:** *Billing and Cost Management → Budgets → Create budget* →
  *Zero spend budget* (avisa no primeiro centavo) e um *Monthly cost budget*
  com o teto que você aceitar, aviso por e-mail.
- **Google:** *Billing → Budgets & alerts → Create budget* → escopo no projeto
  do lab, avisos em 50 %, 90 % e 100 % por e-mail.

Confira: o orçamento aparece na lista com o seu e-mail como destinatário.

## 3. Marcar tudo

Todo recurso leva `env=lab`, para achar o que sobrou de um experimento:

- **AWS:** `default_tags { tags = { env = "lab" } }` no provider.
- **Google:** `default_labels = { env = "lab" }` no provider.
