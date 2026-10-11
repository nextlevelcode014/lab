# Nuvem: Hetzner, AWS e Google Cloud

Esquecer uma instância ligada é o erro mais caro deste repo. Antes do
**primeiro** `terraform apply` numa nuvem:

## 1. Conta ou projeto só do lab

- **AWS:** uma conta separada (AWS Organizations) ou, no mínimo, um usuário
  IAM só do lab: o `lab-terraform`, criado pelo
  [`bootstrap/aws.sh`](../bootstrap/aws.sh) (abaixo).
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

## AWS: usuário do lab (uma vez por conta)

O Terraform do lab entra como `lab-terraform`, que só mexe em buckets
`lab-*` e só cria usuários em `/lab/` com o teto `lab-boundary` anexado.
Esse teto é o que impede a escalada: quem pode criar usuário e dar policy a
ele pode criar um admin, a não ser que todo usuário criado nasça preso a um
teto que ele não consegue tirar. Criar esse usuário exige IAM de admin, por
isso é feito à mão, uma vez.

1. Console da AWS logado como admin → ícone **CloudShell** (barra de cima).
   O CloudShell já vem autenticado, e assim nenhuma chave de admin vai para o
   seu disco.
2. **Actions → Upload file** → `bootstrap/aws.sh` e rode:

   ```bash
   bash aws.sh
   ```

   Na primeira vez, ele imprime a chave do `lab-terraform` (access key e
   secret). Ela aparece uma vez só: guarde no Vaultwarden como "AWS —
   lab-terraform".
3. Na sua máquina:

   ```bash
   aws configure --profile lab    # cole a chave; region eu-central-1
   aws sts get-caller-identity --profile lab
   ```

   Confira: o `Arn` termina em `user/lab-terraform`.

Rodar o script de novo atualiza as policies e não cria outra chave.

## Hetzner

- **Projeto `lab`** na console, com token de API próprio (leitura e
  escrita). O token só enxerga o projeto onde foi criado: é o que impede o
  lab de listar, mudar ou apagar a VPS de produção. Nunca use o token da
  produção aqui.
- **Custo:** a Hetzner cobra por hora com teto mensal por tipo de servidor,
  então esquecer uma VPS ligada custa no máximo o preço mensal dela (veja na
  tela de criação do servidor). O risco que sobra é esquecer por meses:
  depois de cada `destroy`, confira que o projeto `lab` está vazio.
- **Marcar:** a Hetzner não tem rótulo padrão no provider; ponha
  `labels = { env = "lab" }` em cada recurso que aceita (servidor, firewall,
  chave SSH).
