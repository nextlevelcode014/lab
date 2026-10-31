# 09 — Boas práticas de state: fora do git, bucket blindado, refresh com cuidado

Só AWS (profile `lab`). O roadmap resume o tópico em quatro regras: state
nunca no git, backend remoto com trava e versões, states pequenos, e
`terraform refresh` com cuidado. As três primeiras você já praticou no 08.
Aqui você confere o que sobrou delas no disco, fecha o bucket do state, e
vê o refresh apagar algo do state sem perguntar. Depois desfaz isso com as
versões do bucket.

| Diretório | O que cria | Onde fica o state |
|---|---|---|
| `bootstrap/` | o bucket do state: versões, cifra, só TLS, limpeza de versões antigas, contra destroy | local |
| `terraform/` | a "aplicação": um bucket com dois objetos | S3, desde o primeiro `init` |

## Passos

1. **State fora do git e do disco.** Antes de criar algo, procure o que os
   tópicos anteriores deixaram:

   ```bash
   cd ~/Work/dev/lab
   find experimentos -name '*.tfstate*' -not -path '*/.terraform/*'
   find experimentos -name '*.tfstate*' -not -path '*/.terraform/*' -exec grep -l '"secret"' {} +
   git status --short --ignored experimentos/roadmap-terraform/
   ```

   O `.gitignore` da raiz protegeu esses arquivos do git: protegeu de mais
   alguma coisa? Algum ainda descreve recurso que existe na AWS
   (`terraform state list` no diretório dele responde)? Apague os que não
   servem mais. Por último: o `.gitignore` ignora `.terraform/` inteiro, mas
   deixa o `.terraform.lock.hcl` entrar. Por que um e não o outro?

2. **Bucket do state blindado.** Leia o `bootstrap/main.tf` e crie:

   ```bash
   cd experimentos/roadmap-terraform/09-boas-praticas-estado/bootstrap
   terraform init
   terraform apply
   STATE=$(terraform output -raw bucket)
   ```

   Teste a policy, primeiro com HTTPS (o padrão do CLI) e depois com HTTP:

   ```bash
   aws s3 ls --profile lab "s3://$STATE"
   aws s3 ls --profile lab "s3://$STATE" --endpoint-url http://s3.eu-central-1.amazonaws.com
   ```

   E tente apagar o bucket:

   ```bash
   terraform destroy
   ```

   Para cada recurso do `main.tf`, diga de que ele protege o state. O
   `lab-terraform` tem `s3:*` no bucket: por que o pedido em HTTP foi
   recusado mesmo assim? O `destroy` parou antes de perguntar `yes`: o que
   aconteceria sem o `prevent_destroy`, já que o `force_destroy` é `false`?
   A regra de lifecycle apaga versões antigas: o que você ganha com ela, e o
   que perde?

3. **Backend por arquivo, e o que ele cifra.** O `versions.tf` do app tem o
   backend sem bucket, região e profile. Eles vêm de um arquivo:

   ```bash
   cd ../terraform
   terraform -chdir=../bootstrap output -raw backend_config > lab.s3.tfbackend
   cat lab.s3.tfbackend
   terraform init -backend-config=lab.s3.tfbackend
   terraform apply
   aws s3api head-object --profile lab --bucket "$STATE" \
     --key roadmap-09/app.tfstate --query ServerSideEncryption
   jq .backend.config .terraform/terraform.tfstate
   ```

   Salve uma cópia do state, do jeito que alguém faria "por segurança":

   ```bash
   terraform state pull > copia-do-state.json
   git status --short .
   ```

   O state está cifrado no S3. Contra quem isso protege, e contra quem não
   protege? (Pense: quem tem `s3:GetObject` recebe o quê?) Se você tivesse
   passado `access_key` e `secret_key` no `-backend-config`, onde elas iam
   parar? E o git, viu a cópia? Que regra isso ensina sobre cópias do state?
   Apague a `copia-do-state.json`.

4. **Drift, e o `-refresh-only`.** Mude o bucket do app por fora do
   Terraform: um objeto muda de conteúdo, o outro some.

   ```bash
   APP=$(terraform output -raw bucket)
   echo '{"versao": 2}' | aws s3 cp --profile lab - "s3://$APP/config.json"
   aws s3 rm --profile lab "s3://$APP/LEIA-ME.txt"
   ```

   Compare os dois planos (responda `no` a qualquer pergunta):

   ```bash
   terraform plan
   terraform plan -refresh-only
   ```

   O que cada um propõe fazer, e com o quê: com a AWS ou com o state? Num
   drift de verdade, quando você aceitaria o que mudou por fora em vez de
   desfazer? E se aceitar, o que mais precisa mudar além do state?

5. **O refresh sem cuidado, e a volta.** Agora o comando antigo:

   ```bash
   terraform refresh
   terraform state list
   terraform state pull | jq .serial
   ```

   Liste as versões do state, da mais nova para a mais velha:

   ```bash
   aws s3api list-object-versions --profile lab --bucket "$STATE" \
     --prefix roadmap-09/app.tfstate \
     --query "reverse(sort_by(Versions[?Key=='roadmap-09/app.tfstate'], &LastModified))[].[VersionId,LastModified,IsLatest]" \
     --output table
   ```

   Volte para a versão de antes do refresh (a segunda linha), copiando-a
   por cima da atual:

   ```bash
   aws s3api copy-object --profile lab --bucket "$STATE" \
     --key roadmap-09/app.tfstate \
     --copy-source "$STATE/roadmap-09/app.tfstate?versionId=<VersionId-da-segunda-linha>"
   terraform state list
   terraform state pull | jq .serial
   terraform plan
   ```

   O que o `refresh` fez, e o que ele deixou de perguntar? Ele equivale a
   qual combinação de `apply` e opções? Imagine o profile apontando para a
   conta errada, onde nenhum recurso existe: o que o refresh faria com o
   state, e o que o `apply` seguinte tentaria? O `copy-object` voltou o
   `serial`: o `terraform state push` teria deixado? Por que pelo S3 passou?
   Por último: com 500 recursos num state só, em vez de 3, o que muda no
   refresh?

   Feche o drift aplicando:

   ```bash
   terraform apply
   ```

## Destruir

```bash
cd ../terraform && terraform destroy
cd ../bootstrap && terraform destroy
```

O segundo falha: é o `prevent_destroy` do passo 2. Para apagar o bucket do
state, desligue as duas travas no `bootstrap/main.tf`: apague o bloco
`lifecycle` e troque `force_destroy` para `true`. Depois:

```bash
terraform apply     # grava o force_destroy no state
terraform destroy
```

Por que dar dois passos (editar e aplicar, só então destruir) é melhor do
que um `destroy` que já apagasse tudo?

Volte o `bootstrap/main.tf` como estava (`git checkout -- main.tf`) e
confira: `terraform state list` vazio nos dois, nenhum bucket
`lab-roadmap-09-` no console da AWS (*S3 → General purpose buckets*), e
apague o `lab.s3.tfbackend` e os `terraform.tfstate*` locais do
`bootstrap/`.
