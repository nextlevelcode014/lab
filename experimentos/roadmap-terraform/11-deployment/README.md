# 11 — Deployment

Pratique a revisão e a aplicação de um plano salvo. O recurso integrado
`terraform_data` simula um deployment registrando uma versão no state local.

## 1. Prever e salvar o plano

Da raiz do lab, rode:

```bash
cd experimentos/roadmap-terraform/11-deployment/terraform
terraform init
terraform plan
terraform plan -out=deployment.tfplan
terraform show deployment.tfplan
test ! -e terraform.tfstate && echo 'Ainda não há state local'
```

Em um state novo, confira se o plano propõe criar um recurso (`+`) e se
a mensagem confirma que o arquivo de state ainda não existe. O primeiro plano serve para
inspeção. O segundo grava as ações e os valores que você pode revisar e
passar ao `apply`. Planos salvos podem conter dados sensíveis em texto claro,
então trate o arquivo como trataria o state.

## 2. Aplicar o que você revisou

No `main.tf`, altere manualmente o valor padrão de `release` de `"v1"`
para `"v2"`. Essa edição simula uma mudança no código depois da revisão
do plano. Antes de aplicar, preveja qual versão aparecerá no output.

```bash
terraform apply deployment.tfplan
terraform state list
terraform output -raw release_aplicada
terraform plan
```

Confira a versão aplicada e procure no novo plano uma atualização no lugar
(`~`). Passar um plano salvo ao `apply` já conta como aprovação, por isso
a revisão acontece antes do comando.

## 3. Aplicar a configuração atual

```bash
terraform apply
terraform output -raw release_aplicada
terraform plan
```

Leia o plano que o `apply` acabou de gerar e digite `yes` se ele mostrar
a atualização esperada. A confirmação é manual para você conferir a
mudança antes de gravá-la. Verifique o output e se o último plano indica
que a configuração e o state já estão de acordo.

## Perguntas de revisão

- O que mudou no state entre rodar `plan` e rodar `apply`?
- Qual versão saiu do plano salvo após você editar o HCL? Por quê?
- Por que o segundo `apply` pediu confirmação?

## Limpeza

```bash
terraform destroy
terraform state list
rm -- deployment.tfplan
```

Confira o plano de destruição e digite `yes` para remover o recurso do
state. O `state list` deve ficar vazio. Restaure manualmente o valor padrão
de `release` para `"v1"` no `main.tf` e confira com
`git diff -- main.tf` para poder repetir o exercício desde o início.

## Referências

- [terraform plan](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [terraform apply](https://developer.hashicorp.com/terraform/cli/commands/apply)
- [terraform_data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)
