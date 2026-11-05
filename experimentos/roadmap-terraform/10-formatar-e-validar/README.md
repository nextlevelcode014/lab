# 10 — Formatar e validar

Pratique três verificações locais em uma configuração com problemas
intencionais. Você precisa de Terraform e TFLint no PATH. O exercício usa
apenas variáveis e um output, sem providers externos ou recursos.

## 1. Preparar a cópia

Na raiz do lab, rode:

```bash
exercicio_dir=$(mktemp -d)
cp experimentos/roadmap-terraform/10-formatar-e-validar/terraform/main.tf.example "$exercicio_dir/main.tf"
cd "$exercicio_dir"
terraform init -backend=false
```

Confira se o Terraform informa que a inicialização foi concluída. A extensão
`.example` preserva os erros intencionais no repositório. A cópia com extensão
`.tf` é a configuração que você vai alterar.

## 2. Conferir a formatação e a referência

Antes de rodar, preveja o que cada comando vai apontar.

```bash
terraform fmt -check -diff
terraform validate
```

O primeiro comando mostra o diff sem reescrever o arquivo. O segundo deve
indicar uma referência a uma variável não declarada. Rode `terraform fmt`
e confira se o diff de formatação desaparece, depois corrija manualmente
a referência no output e rode `terraform validate` até passar. A escolha
da variável correta depende do que o output deve representar.

## 3. Encontrar uma declaração sem uso

```bash
tflint --only=terraform_unused_declarations
```

Confira qual variável sobrou. Remova a declaração manualmente, depois rode
os três checks de novo. O linter aponta a declaração, mas cabe a você decidir
se a variável deve ser removida ou usada.

```bash
terraform fmt -check -diff
terraform validate
tflint --only=terraform_unused_declarations
```

## Perguntas de revisão

- O que o `fmt` conseguiu corrigir sozinho?
- Por que uma variável sem uso pode passar no `validate`?
- O que o TFLint acrescentou à verificação?

## Limpeza

O exercício só cria arquivos locais. Para apagar a cópia descartável:

```bash
cd -
rm -- "$exercicio_dir/main.tf"
rmdir -- "$exercicio_dir"
test ! -e "$exercicio_dir"
```
