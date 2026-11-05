# 12 — Clean Up

Pratique `terraform destroy` com dois recursos `terraform_data` no state
local. A aplicação depende do ambiente por meio de uma referência no HCL.

## 1. Criar o ambiente descartável

Da raiz do lab, rode:

```bash
cd experimentos/roadmap-terraform/12-limpeza/terraform
terraform init
terraform apply
terraform state list
```

Confira se o plano prevê duas criações e digite `yes` para executá-lo.
A confirmação manual dá a você a chance de conferir o plano. Verifique
se os dois recursos aparecem no state.

## 2. Revisar e cancelar uma destruição

```bash
terraform plan -destroy
terraform destroy
terraform state list
```

Confira se a prévia indica duas destruições (`-`). Quando o
`terraform destroy` pedir confirmação, digite `no` para praticar o
cancelamento. Confira se os dois recursos continuam no state.

## 3. Destruir e verificar

```bash
terraform destroy
terraform state list
terraform plan -destroy
terraform plan
```

Revise o plano que o `destroy` apresentou e digite `yes` se listar apenas
os dois recursos do exercício. Observe nos logs qual recurso é removido
primeiro. O `state list` deve ficar vazio. Compare a prévia de destruição
com o plano normal. Pare após a comparação para manter o ambiente limpo.

## Perguntas de revisão

- Por que rodar `terraform plan -destroy` antes de confirmar a destruição?
- Qual recurso foi destruído primeiro? Como a referência no HCL explica a ordem?
- Por que o plano normal propôs criações com o state vazio?

## Referências

- [terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy)
- [Modos de planejamento](https://developer.hashicorp.com/terraform/cli/commands/plan#planning-modes)
