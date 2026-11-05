# 13 — Inspecionar e modificar o state

Use dois recursos `terraform_data` para comparar a configuração, o plano
e o state. Toda a prática usa o backend local e o provider integrado.

## 1. Inspecionar

Da raiz do lab, rode:

```bash
cd experimentos/roadmap-terraform/13-inspecionar-state/terraform
terraform init
terraform plan -out=criacao.tfplan
terraform show criacao.tfplan
terraform apply criacao.tfplan
terraform graph
terraform state list
terraform state show terraform_data.aplicacao
terraform output -raw aplicacao_id
printf '\n'
terraform show
```

Antes de aplicar, confira as duas criações no plano salvo. Depois, procure
no DOT do grafo a dependência entre a aplicação e o ambiente. Compare
o endereço listado no state, o ID do recurso e o valor do output. O
`show` sem argumento exibe o state atual.

## 2. Mover um endereço e substituir um recurso

Anote o ID retornado pelo output. No `main.tf`, renomeie manualmente o
recurso `aplicacao` para `servico` e ajuste a referência no output. Mantenha
o nome do output. A edição simula uma refatoração do HCL.

```bash
terraform plan
terraform state mv terraform_data.aplicacao terraform_data.servico
terraform state list
terraform state show terraform_data.servico
terraform plan
```

Compare os planos antes e depois de mover o endereço. Confira o ID para
descobrir se o movimento preservou a instância. O plano após o movimento
deve indicar que não há mudanças.

```bash
terraform apply -replace=terraform_data.servico
terraform output -raw aplicacao_id
printf '\n'
```

Confira se o plano propõe substituir somente o serviço e digite `yes`.
A confirmação é manual para revisar quais objetos serão substituídos.
Compare o ID com o anotado anteriormente.

## 3. Copiar o state e esquecer um vínculo

Rode no diretório `terraform/` do exercício:

```bash
copia_dir=$(mktemp -d)
cp main.tf "$copia_dir/"
terraform state pull > "$copia_dir/copia.tfstate"
(
  cd "$copia_dir" || exit
  terraform init &&
    terraform state push copia.tfstate &&
    terraform state list &&
    terraform state rm -dry-run terraform_data.servico &&
    terraform state rm -backup=antes-rm.tfstate terraform_data.servico &&
    terraform state list &&
    terraform plan
)
terraform state list
```

O `push` escreve a cópia em um backend local vazio, separado do original.
Confira os dois endereços antes do `rm` e apenas o ambiente depois dele.
Compare o plano da cópia com a listagem do state original. Em um backend
com state existente, o Terraform protege contra lineage diferente e
serial de destino mais recente. Trate os snapshots como dados sensíveis.

## 4. Interpretar duas operações de manutenção

- `terraform state replace-provider ORIGEM DESTINO` troca o endereço de
  origem do provider registrado no state. Exemplo de uso é migrar para um
  fork compatível. Atualize também o endereço declarado no HCL. Aqui o
  único provider é integrado, então a operação fica para leitura.
- `terraform force-unlock LOCK_ID` libera um lock de state que ficou
  preso em um backend compatível. Só se aplica após confirmar que a
  operação que detinha o lock terminou e que o desbloqueio automático
  falhou. No backend local, outro processo não pode liberar esse lock
  pelo comando.

## Perguntas de revisão

- Que informação você encontrou no grafo, no `state list` e no `show`?
- O que aconteceu com o ID após `state mv` e após `apply -replace`?
- Por que o plano da cópia propôs uma criação depois do `state rm`?
- O que você precisaria conferir antes de usar `force-unlock`?

## Limpeza

No diretório original, rode `terraform destroy`. Confira se o plano
lista as duas remoções e digite `yes`. Depois confira se
`terraform state list` ficou vazio e remova os arquivos de prática:

```bash
rm -- criacao.tfplan terraform.tfstate terraform.tfstate.backup
rm -f -- terraform.tfstate.*.backup
rm -- "$copia_dir"/{main.tf,copia.tfstate,terraform.tfstate,antes-rm.tfstate}
rmdir -- "$copia_dir"
```

Restaure manualmente o nome `aplicacao` no recurso e na referência do
output. Confira que `git diff -- main.tf` está vazio para repetir o roteiro.

## Referências

- [Comandos de state](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Storage e locking do state](https://developer.hashicorp.com/terraform/language/state/backends)
- [force-unlock](https://developer.hashicorp.com/terraform/cli/commands/force-unlock)
