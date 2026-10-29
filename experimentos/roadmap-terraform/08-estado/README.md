# 08 — State: segredos, backend remoto, versões, trava, import e divisão

Só AWS (profile `lab`). Até aqui o state foi um `terraform.tfstate` local,
que ninguém mais vê. Este tópico leva o state para um bucket S3 e olha o que
isso resolve e o que não resolve. São três projetos, cada um com state
próprio:

| Diretório | O que cria | Onde fica o state |
|---|---|---|
| `bootstrap/` | o bucket do state (versionado, sem acesso público) | local |
| `terraform/` | a "aplicação": um bucket e um usuário IAM com chave | local, depois S3 (passo 2) |
| `consumidor/` | um objeto no bucket do app, lendo os outputs dele | S3 |

O que está no git é o ponto de partida: o passo 2 manda você escrever o
`backend` do `terraform/`, e o passo 5, o import.

## Antes

```bash
cd experimentos/roadmap-terraform/08-estado/terraform
terraform init
terraform apply
```

## Passos

1. **Segredo no state.** O `aws_iam_access_key` gera uma chave de acesso de
   verdade (presa ao `lab-boundary`, sem policy nenhuma). Nenhum output a
   expõe. Procure mesmo assim:

   ```bash
   terraform output
   terraform state show aws_iam_access_key.app
   grep -n '"secret"' terraform.tfstate
   ```

   O `state show` esconde a secret; o arquivo, não. No tópico 7 o segredo
   chegou ao state porque você o declarou numa variável. E aqui, quem o pôs
   lá? Daria para escrever o código de um jeito que a secret não fosse para o
   state? Quem tem uma cópia deste arquivo agora pode fazer o quê?

2. **Remote state.** Crie o bucket do state:

   ```bash
   cd ../bootstrap
   terraform init
   terraform apply
   cd ../terraform
   ```

   No `versions.tf` do `terraform/`, dentro do bloco `terraform`:

   ```hcl
   backend "s3" {
     key          = "roadmap-08/app.tfstate"
     region       = "eu-central-1"
     profile      = "lab"
     use_lockfile = true
   }
   ```

   O bucket fica de fora porque o nome tem sufixo aleatório, e um bloco
   `backend` não aceita variável. Ele entra no `init`, lido do output do
   bootstrap:

   ```bash
   terraform init -migrate-state \
     -backend-config="bucket=$(terraform -chdir=../bootstrap output -raw bucket)"
   ```

   Responda `yes` à cópia e confira:

   ```bash
   terraform plan
   ls -la terraform.tfstate*
   grep -c '"secret"' terraform.tfstate terraform.tfstate.backup
   cat .terraform/terraform.tfstate
   aws s3 ls --profile lab "s3://$(terraform -chdir=../bootstrap output -raw bucket)/roadmap-08/"
   ```

   O `plan` disse *No changes*: por quê, se o state saiu do disco? O que
   sobrou na sua máquina, e ainda tem a secret? (Se tiver, apague esses
   arquivos.) O `.terraform/terraform.tfstate` não é o state: o que ele
   guarda? Por último: mudar para o S3 tirou o segredo do state? O que
   mudou, então?

3. **Versionamento.** No `variables.tf`, troque o `default` da `descricao`
   para `"bucket da aplicacao v2"` e aplique:

   ```bash
   terraform apply
   ```

   Sem acento nem vírgula de propósito: na criação a tag vai pela API do S3,
   que aceita UTF-8, mas na alteração o provider usa o `TagResource` do S3
   Control, que só aceita letras ASCII, números, espaço e `+ - = . _ : / @`.

   Liste as versões do state e leia a mais antiga:

   ```bash
   STATE=$(terraform -chdir=../bootstrap output -raw bucket)
   aws s3api list-object-versions --profile lab --bucket "$STATE" \
     --prefix roadmap-08/app.tfstate \
     --query "Versions[?Key=='roadmap-08/app.tfstate'].[VersionId,LastModified,IsLatest]" \
     --output table
   aws s3api get-object --profile lab --bucket "$STATE" \
     --key roadmap-08/app.tfstate --version-id <VersionId-mais-antigo> antigo.tfstate
   jq '{serial, lineage}' antigo.tfstate
   terraform state pull | jq '{serial, lineage}'
   rm antigo.tfstate
   ```

   Quantas versões existem, e qual operação criou cada uma? O que o `serial`
   conta, e o que o `lineage` identifica? Se um `apply` estragasse o state,
   como você voltaria? E por que não guardar o state no git, que também tem
   histórico?

4. **Trava (locking).** Abra dois terminais em `terraform/`. No primeiro,
   comece um apply e **pare no prompt** (não responda):

   ```bash
   terraform apply -var descricao="bucket da aplicacao v3"
   ```

   No segundo:

   ```bash
   terraform plan
   aws s3 ls --profile lab "s3://$(terraform -chdir=../bootstrap output -raw bucket)/roadmap-08/"
   terraform plan -lock-timeout=2m
   ```

   Com o último `plan` esperando, volte ao primeiro terminal e responda `no`.
   O que o segundo `plan` mostrou de cara, e o que apareceu no bucket
   enquanto o primeiro esperava? O que aconteceu com o `plan` que usou
   `-lock-timeout` quando você respondeu `no`? Se o primeiro terminal
   tivesse caído (rede, `kill -9`) no meio do apply, o que sobraria no
   bucket, e como você sairia disso? (O comando é do tópico 13; aqui basta
   dizer o que ele precisaria fazer.)

5. **Import.** Crie um bucket à mão, fora do Terraform:

   ```bash
   MANUAL=lab-roadmap-08-manual-$(date +%s)
   aws s3api create-bucket --profile lab --bucket "$MANUAL" \
     --region eu-central-1 \
     --create-bucket-configuration LocationConstraint=eu-central-1
   echo "$MANUAL"
   ```

   Num arquivo `importar.tf` (com o nome que o `echo` mostrou):

   ```hcl
   import {
     to = aws_s3_bucket.manual
     id = "lab-roadmap-08-manual-..."
   }
   ```

   Não escreva o `resource`: peça para o Terraform gerar.

   ```bash
   terraform plan -generate-config-out=importado.tf
   ```

   Leia o `importado.tf`. (Se o `plan` reclamar de atributo conflitante, apague
   a linha que ele aponta: o gerador escreve tudo o que leu da AWS, e alguns
   argumentos se excluem.) Rode `terraform plan` de novo e depois
   `terraform apply`.

   O import mudou alguma coisa na AWS? Além de importar, o plan quis mudar
   algo no bucket manual: o quê, e por quê? Antes do bloco `import` existia o
   comando `terraform import aws_s3_bucket.manual <nome>`: o que o bloco faz
   que o comando não fazia? Depois do apply, o que acontece se o bloco
   `import` ficar no código?

6. **Dividir o state.** O `consumidor/` tem state próprio, no mesmo bucket,
   e lê os outputs do app pelo `terraform_remote_state`:

   ```bash
   cd ../consumidor
   STATE=$(terraform -chdir=../bootstrap output -raw bucket)
   terraform init -backend-config="bucket=$STATE"
   terraform apply -var bucket_state="$STATE"
   aws s3 ls --profile lab "s3://$STATE/roadmap-08/"
   terraform state pull | jq '.resources[] | {type, name}'
   terraform state pull | jq '.resources[] | select(.type == "terraform_remote_state") | .instances[0].attributes.outputs'
   ```

   O state do consumidor guarda o quê do app? Para ler dois outputs, o
   consumidor precisa de `s3:GetObject` no `app.tfstate`: o que mais essa
   permissão deixa ele ler? Se o app trocasse o nome do bucket, o
   `LEIA-ME.txt` mudaria sozinho? Por último: que vantagem tem ter dois
   states em vez de pôr o objeto no `terraform/`, e que custo isso trouxe?

## Destruir

A ordem importa: quem lê destrói primeiro, e o bucket do state por último.

```bash
cd ../consumidor && terraform destroy -var bucket_state="$(terraform -chdir=../bootstrap output -raw bucket)"
cd ../terraform  && terraform destroy
cd ../bootstrap  && terraform destroy
```

O `terraform/` leva junto o bucket importado. O que aconteceria se você
destruísse o `terraform/` antes do `consumidor/`? E se destruísse o
`bootstrap/` antes dos outros dois?

Confira: `terraform state list` vazio nos três, nenhum bucket
`lab-roadmap-08-` no console da AWS (*S3 → General purpose buckets*) e
nenhum usuário `roadmap-08-app` em *IAM → Users*. Apague também os
`terraform.tfstate*` que sobraram no `terraform/` do passo 2.
