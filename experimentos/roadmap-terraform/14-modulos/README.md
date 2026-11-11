# 14 — Módulos

Pratique root e child modules, reutilização, entradas, saídas e leitura de
um módulo publicado. A prática usa apenas `terraform_data`, provider
integrado e backend local. Não exige credenciais, downloads de providers
ou acesso ao Proxmox. As portas são dados ilustrativos: nenhum serviço sobe.

## Modelo mental

Um módulo é um diretório de arquivos `.tf`. O **root module** é aquele onde
você executa Terraform; um **child module** é chamado por um bloco `module`.
`source` escolhe o código, variáveis formam suas entradas e outputs formam
suas saídas. Duas chamadas reutilizam o mesmo código com instâncias distintas.
Neste exercício, ambas ficam no mesmo state do root: módulo não é backend.

```text
terraform/                  # root: chamadas e output agregado
├── main.tf
├── outputs.tf
├── versions.tf
└── modules/servico/         # child: implementação reutilizável
    ├── README.md
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── versions.tf
```

Terraform reúne os `.tf` de cada diretório; os nomes dos arquivos são uma
convenção de organização. Subdiretórios só entram quando chamados.

## 1. Ler o contrato e inicializar

Pré-requisito: Terraform >= 1.4 já instalado. Da raiz do lab:

```bash
cd experimentos/roadmap-terraform/14-modulos/terraform
terraform version
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

Leia primeiro as duas chamadas em `main.tf` e o README de `modules/servico`.
Localize cada argumento na variável correspondente e siga o caminho do
output do child até o output do root. Confira que o plano contém somente
duas criações `terraform_data`, sob `module.site` e `module.api`.
O init registra os módulos locais; não provisiona recursos.

## 2. Comparar duas instâncias

```bash
terraform apply
terraform state list
terraform state show 'module.site.terraform_data.servico'
terraform state show 'module.api.terraform_data.servico'
terraform output -json servicos
```

Revise as duas criações antes de digitar `yes`. A confirmação é manual
porque cabe a você conferir o plano. Compare os endereços, IDs e portas.
Localize o único `terraform.tfstate` no root; não rode apply no child.

## 3. Alterar a entrada de uma chamada

No `main.tf` do root, mude **somente** a porta de `site` de `8080` para
`8081`. Essa edição é manual para praticar o contrato entre os módulos.

```bash
terraform plan
terraform apply
terraform output -json servicos
```

Antes de confirmar, verifique que só o recurso de `module.site` será
atualizado, sem criação ou destruição. Compare os IDs com os anteriores.
Depois, remova o argumento `porta` da chamada `api`, rode `terraform plan`
e descubra qual valor o módulo passa a usar. Não aplique essa segunda
mudança; restaure `porta = 3000` e confira que o plano fica sem mudanças.

## 4. Criar uma saída do módulo

Faça manualmente estas alterações, pois o objetivo é você escrever e
conectar o contrato de saída:

1. No `outputs.tf` do child, crie `output "nome_completo"`, com descrição,
   expondo `terraform_data.servico.output.nome`.
2. No `outputs.tf` do root, crie `output "nome_site"`, com descrição,
   usando `module.site.nome_completo`.

```bash
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output -raw nome_site
printf '\n'
```

Confira que a saída é `lab-site` e que nenhuma alteração de recurso é
necessária. O root acessa o child pelos outputs; tentar atravessar o
módulo para acessar diretamente seus recursos não faz parte do contrato.

## 5. Ler um módulo publicado

Esta parte é leitura no navegador, sem instalar ou executar o módulo AWS.
Abra o [VPC 6.0.1 no Registry](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/6.0.1)
e consulte documentação, inputs, outputs, requisitos e código-fonte da
mesma versão. Registre um input obrigatório, se houver, um opcional e um
output. Identifique também as versões exigidas de Terraform e do provider.

Interprete este exemplo de chamada; **não o copie para o exercício local**:

```hcl
module "rede" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "lab-exemplo"
  cidr = "10.60.0.0/16"
}
```

`source` identifica o módulo no Registry; `version` fixa a versão do
módulo, não do provider. Para um `source` local como `./modules/servico`,
não se usa `version`. Após adicionar uma chamada ou mudar sua origem,
rode `terraform init`. Para atualizar um módulo já instalado dentro da
constraint, use `terraform init -upgrade` e revise o plano.

O `.terraform.lock.hcl` fixa providers, não versões de módulos remotos.
Por isso, revise o código e fixe versões dos módulos; em fontes Git, um
`ref` com SHA fixa o commit. A leitura é manual para exercitar a escolha
de dependências antes de instalar ou provisionar qualquer coisa.

## Boas práticas para observar

- Mantenha o módulo pequeno e com uma responsabilidade clara; evite uma
  árvore profunda de módulos que só repassam argumentos.
- Documente entradas, saídas e restrições; use tipos, descrições e validações.
- Configure providers no root e declare requisitos nos módulos que os usam.
  Aqui não há provider externo para configurar.
- Exponha apenas os outputs necessários e passe dependências como entradas.
- Não edite código baixado em `.terraform/`: a correção pertence à origem
  do módulo e deve chegar por uma versão revisada.

## Perguntas de revisão

1. Qual diretório é o root module neste exercício? O que faz `servico`
   ser um child module?
   R:
2. Por que as duas chamadas têm IDs diferentes apesar de usarem o mesmo
   código? Quais endereços apareceram no state? Quantos states existem?
   R:
3. Qual recurso mudou quando você alterou só a porta de `site`? O ID mudou?
   Qual porta o plano escolheu quando você omitiu a entrada em `api`?
   R:
4. Como o valor de `nome_site` atravessa o child até chegar ao root?
   Por que declarar um output no child não basta para `terraform output`?
   R:
5. No módulo publicado, quais input, output e requisitos você encontrou?
   O que `source`, `version` e `.terraform.lock.hcl` controlam?
   R:
6. Se você mudar o código de `modules/servico`, quais chamadas podem ser
   afetadas? Por que evitar editar a cópia de um módulo em `.terraform/`?
   R:

## Limpeza

No `terraform/` deste exercício:

```bash
terraform plan -destroy
terraform destroy
terraform state list
```

Confira as duas remoções antes de confirmar com `yes`; depois, a listagem
do state deve estar vazia. Mantenha os arquivos de state locais, ignorados
pelo Git, para poder inspecioná-los. Restaure manualmente a porta de `site`
para `8080` e remova os dois outputs adicionados no passo 4. Preserve suas
respostas no README. Confira as restaurações da prática:

```bash
git diff -- main.tf outputs.tf modules/servico/outputs.tf
```

O diff desses arquivos deve estar vazio. Essa restauração é manual para
rever as alterações feitas; um próximo plano voltará a propor as duas
criações porque o HCL continua declarando os recursos.

## Referências

- [Visão geral de módulos](https://developer.hashicorp.com/terraform/language/modules)
- [Uso, fontes, versões e outputs](https://developer.hashicorp.com/terraform/language/modules/configuration)
- [Estrutura padrão de módulos](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
