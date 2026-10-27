# 06 — Variáveis: entrada, tipos, arquivos, locals, ambiente e validação

Só AWS desta vez (profile `lab`, como no [tópico 4](../04-providers/README.md)):
sem VM, sem Tailscale. O `terraform/` começa com dois buckets S3 vazios
escritos à mão, com `"dev"` e as tags repetidos nos dois. Cada passo troca um
valor fixo por variável ou local, e o projeto termina com um bucket por item de
um mapa.

O que está no git é o projeto como o passo 6 deixa; para refazer do começo,
volte o `main.tf` para os dois buckets fixos e apague o `variables.tf`.

## Antes

```bash
cd experimentos/roadmap-terraform/06-variaveis/terraform
terraform init
terraform apply      # dados e logs, com "dev" escrito à mão
```

## Passos

1. **Variável de entrada.** Num `variables.tf`:

   ```hcl
   variable "ambiente" {
     type        = string
     description = "dev, hml ou prod: entra no nome e nas tags dos buckets"
   }
   ```

   Troque os quatro `"dev"` do `main.tf` por `var.ambiente` (no
   `bucket_prefix`, por interpolação: `"lab-roadmap-06-${var.ambiente}-dados-"`).
   Rode `terraform plan` **sem** passar valor: o que acontece? Responda `dev`.
   Agora do jeito que um CI rodaria, sem ninguém para responder:

   ```bash
   terraform plan -input=false
   terraform plan -input=false -var ambiente=dev
   ```

2. **Local.** O prefixo e as tags ainda se repetem. No `main.tf`:

   ```hcl
   locals {
     prefixo = "lab-roadmap-06-${var.ambiente}"
     tags = {
       ambiente = var.ambiente
       dono     = "nextlevelcode"
     }
   }
   ```

   Use `"${local.prefixo}-dados-"` e `tags = local.tags` nos dois buckets.
   `terraform plan -var ambiente=dev` deve dizer *No changes*: o valor final é
   o mesmo. Tente mudar o local por fora:

   ```bash
   terraform plan -var ambiente=dev -var prefixo=outro
   ```

3. **Tipos.** Troque os dois buckets por um só, com `for_each` num mapa de
   objetos. No `variables.tf`:

   ```hcl
   variable "buckets" {
     type = map(object({
       descricao     = string
       versionamento = optional(bool, false)
     }))
   }
   ```

   No `main.tf`, no lugar de `dados` e `logs`:

   ```hcl
   resource "aws_s3_bucket" "b" {
     for_each      = var.buckets
     bucket_prefix = "${local.prefixo}-${each.key}-"
     tags          = merge(local.tags, { descricao = each.value.descricao })
   }

   resource "aws_s3_bucket_versioning" "b" {
     for_each = { for nome, b in var.buckets : nome => b if b.versionamento }
     bucket   = aws_s3_bucket.b[each.key].id
     versioning_configuration {
       status = "Enabled"
     }
   }
   ```

   (Os endereços mudam de `aws_s3_bucket.dados` para `aws_s3_bucket.b["dados"]`,
   então os buckets são recriados, como no passo 3 do tópico 5. Vazios, tanto
   faz.) Ainda sem aplicar, veja como o Terraform enxerga o valor:

   ```bash
   terraform console -var ambiente=dev \
     -var 'buckets={dados={descricao="dados da aplicação",versionamento=true},logs={descricao=42}}'
   > var.buckets
   ```

   O que virou o `42`? E o `versionamento` do `logs`, que você não passou?
   Saia (`exit`) e tente `versionamento="talvez"` no lugar de `true` com
   `terraform plan`. Por que o `42` passou e o `"talvez"` não?

4. **Arquivo de definição.** Digitar o mapa toda vez não escala. Crie o
   `terraform.tfvars`:

   ```hcl
   ambiente = "dev"
   buckets = {
     dados = { descricao = "dados da aplicação", versionamento = true }
     logs  = { descricao = "logs de acesso" }
   }
   ```

   `terraform plan`, sem nenhum `-var`, e aplique. Agora um `prod.tfvars` só
   com `ambiente = "prod"`, e:

   ```bash
   terraform plan -var-file=prod.tfvars
   ```

   O `buckets` veio de onde, se o `prod.tfvars` não tem? Não aplique.
   (O `.gitignore` do lab ignora `terraform.tfvars` e `*.auto.tfvars`, que
   costumam ter segredo; um `prod.tfvars` com outro nome entraria no git.)

5. **Variável de ambiente e precedência.** O `terraform console` mostra o valor
   final sem planejar nada. Com o `terraform.tfvars` dizendo `dev`:

   ```bash
   echo 'var.ambiente' | TF_VAR_ambiente=hml terraform console
   ```

   Quem ganhou, a variável de ambiente ou o arquivo? Agora um
   `zz.auto.tfvars` com `ambiente = "hml"`, e de novo:

   ```bash
   echo 'var.ambiente' | terraform console
   echo 'var.ambiente' | terraform console -var ambiente=dev
   ```

   (Pode aparecer um *Warning* antes do valor: é a validação do passo 6, se
   você já chegou lá.) Monte a ordem, do mais fraco para o mais forte:
   `default`, `TF_VAR_`, `terraform.tfvars`, `*.auto.tfvars`, `-var`.
   Apague o `zz.auto.tfvars` no fim.

6. **Validação.** No `variable "ambiente"`:

   ```hcl
   validation {
     condition     = contains(["dev", "hml", "prod"], var.ambiente)
     error_message = "ambiente tem que ser dev, hml ou prod."
   }
   ```

   E duas no `variable "buckets"`: o nome do bucket (a chave do mapa) e uma
   regra que depende de **outra** variável (Terraform 1.9+):

   ```hcl
   validation {
     condition     = alltrue([for nome in keys(var.buckets) : can(regex("^[a-z0-9]{1,10}$", nome))])
     error_message = "Nome de bucket: só minúsculas e números, até 10 caracteres."
   }

   validation {
     condition     = var.ambiente != "prod" || alltrue([for b in values(var.buckets) : b.versionamento])
     error_message = "Em prod, todo bucket tem versionamento = true."
   }
   ```

   Faça cada uma falhar com `terraform plan`:

   ```bash
   terraform plan -var ambiente=producao
   terraform plan -var-file=prod.tfvars
   ```

   e uma chave `Logs_2026` no `terraform.tfvars`. Em que momento o erro
   aparece: antes ou depois de o Terraform falar com a AWS? Por que isso
   importa? Volte o `terraform.tfvars` ao normal.

## Destruir

```bash
terraform destroy
```

O `destroy` também precisa de valor para toda variável sem `default`: com o
`terraform.tfvars` no lugar ele lê sozinho; sem ele, pergunta (ou falha com
`-input=false`).

Confira: `terraform state list` vazio e nenhum bucket `lab-roadmap-06-` no
console da AWS (*S3 → General purpose buckets*).
