# 07 — Outputs: sintaxe, valores sensíveis e precondições

Só AWS de novo (profile `lab`). O `terraform/` começa onde o
[tópico 6](../06-variaveis/README.md) terminou, enxugado: dois buckets S3
vazios num `for_each`, com o mapa como `default` (sem `.tfvars`). Até aqui o
projeto cria coisas mas não **devolve** nada; cada passo acrescenta um output
num `outputs.tf` e vê quem consegue ler esse valor, e como.

O que está no git é o projeto como o passo 4 deixa; para refazer do começo,
apague o `outputs.tf` e as variáveis `chave_api` e `backup`.

## Antes

```bash
cd experimentos/roadmap-terraform/07-outputs/terraform
terraform init
terraform apply      # dados (com versionamento) e logs
```

## Passos

1. **Sintaxe.** Antes de escrever qualquer output:

   ```bash
   terraform output
   ```

   Agora um `outputs.tf`:

   ```hcl
   output "nomes" {
     description = "Nome real de cada bucket, pela chave do mapa"
     value       = { for chave, b in aws_s3_bucket.b : chave => b.bucket }
   }

   output "arn_dados" {
     value = aws_s3_bucket.b["dados"].arn
   }
   ```

   `terraform plan`: o bloco *Changes to Outputs* já mostra os nomes reais,
   não *(known after apply)*. Por quê? E o `terraform output` de agora há
   pouco, por que não achou nada, se o bucket já existia? Aplique e leia de
   cada jeito:

   ```bash
   terraform output
   terraform output nomes
   terraform output -json
   terraform output -raw arn_dados
   terraform output -raw nomes
   ```

   O último falha: por quê? Agora o uso de verdade, um script lendo o output:

   ```bash
   aws s3api head-bucket --profile lab --bucket "$(terraform output -json nomes | jq -r .dados)"
   ```

   Quando você usaria o formato padrão, o `-json` e o `-raw`?

2. **Outputs sensíveis.** No `variables.tf`:

   ```hcl
   variable "chave_api" {
     type      = string
     sensitive = true
     default   = "segredo-de-mentira-123"
   }
   ```

   E no `outputs.tf`:

   ```hcl
   output "chave_api" {
     value = var.chave_api
   }
   ```

   `terraform plan`: o que o Terraform recusa, e por quê? Acrescente
   `sensitive = true` no output, aplique e procure o segredo:

   ```bash
   terraform output
   terraform output chave_api
   terraform output -json | jq .chave_api
   grep -n segredo terraform.tfstate
   ```

   Onde ele aparece escondido e onde aparece em claro? Então, do que o
   `sensitive = true` protege, e do que **não** protege?

   Por último, um output que só conta os caracteres:

   ```hcl
   output "tamanho_chave" {
     value = length(var.chave_api)
   }
   ```

   Um número não é segredo; por que o `plan` reclama mesmo assim? Troque por
   `nonsensitive(length(var.chave_api))` e confira que passa. (Nunca use
   `nonsensitive()` no segredo em si: é desligar o aviso, não o risco.)

3. **Precondições.** Uma ferramenta de backup vai ler o nome do bucket por um
   output, e ela só funciona com versionamento ligado. No `variables.tf`:

   ```hcl
   variable "backup" {
     type        = string
     description = "Chave do bucket que a ferramenta de backup vai ler"
     default     = "dados"
   }
   ```

   No `outputs.tf`:

   ```hcl
   output "bucket_backup" {
     value = aws_s3_bucket.b[var.backup].bucket

     precondition {
       condition     = contains(keys(var.buckets), var.backup)
       error_message = "backup = \"${var.backup}\" não é chave de var.buckets."
     }

     precondition {
       condition     = var.buckets[var.backup].versionamento
       error_message = "O bucket de backup precisa de versionamento = true."
     }
   }
   ```

   Aplique (com `dados` passa) e faça falhar:

   ```bash
   terraform plan -var backup=logs
   terraform plan -var backup=fotos
   ```

   Com `logs`, o plan falhou: algum bucket seria criado ou alterado? Com
   `fotos`, quantos erros aparecem, e de onde vem o segundo? No tópico 6 a
   `validation` também barrava valor ruim: o que a `precondition` num output
   protege que a `validation` de uma variável não protege?

4. **`depends_on` num output.** O `bucket_backup` só cita
   `aws_s3_bucket.b`, então quem lê o nome pode recebê-lo antes de o
   versionamento existir. Veja de quem o output depende:

   ```bash
   terraform graph -type=plan | grep 'output.bucket_backup'
   ```

   Acrescente no `output "bucket_backup"`:

   ```hcl
   depends_on = [aws_s3_bucket_versioning.b]
   ```

   e rode o `graph` de novo. Que seta mudou? Por que a seta para
   `aws_s3_bucket.b` some, se o output continua lendo esse recurso? No root
   module o efeito não aparece no `apply`; em que situação ele faz
   diferença? (Dica: o tópico 14, *Modules — Inputs / Outputs*.)

## Destruir

```bash
terraform destroy
terraform output
```

O `terraform output` depois do `destroy` responde o mesmo do começo do
passo 1: os outputs moram no state, e o state ficou vazio.

Confira: `terraform state list` vazio e nenhum bucket `lab-roadmap-07-` no
console da AWS (*S3 → General purpose buckets*). (O usuário `lab-terraform`
não tem `s3:ListAllMyBuckets`, então `aws s3 ls` dá *AccessDenied*: o
console é o caminho.)
