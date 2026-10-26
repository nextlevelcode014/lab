# 04 — Providers: registry, configuração e versões

O `terraform/` começa com o projeto do tópico 3 (VM `roadmap-04`, VMID 990,
desligada). Os passos mexem só no que liga o Terraform ao Proxmox e, a partir
do passo 5, à AWS: de onde vem o provider, como ele é configurado e qual
versão entra. O que está no git é o projeto como o passo 8 deixa (com o
`aws.tf`); para refazer do começo, apague o `aws.tf` e o `aws` do
`versions.tf`.

## Antes

Tailscale ligado e o token no tfvars, como no [tópico 1](../01-introducao/README.md):

```bash
cd experimentos/roadmap-terraform/04-providers/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
```

A partir do passo 5 também entra a AWS, com o profile `lab` (usuário
`lab-terraform`, criado uma vez como em [docs/nuvem.md](../../../docs/nuvem.md)).
Buckets vazios não custam nada. Se a máquina ainda não tem o profile, crie à
mão com a chave do Vaultwarden ("AWS — lab-terraform"); não é automatizável
porque a chave só existe lá:

```bash
mkdir -p ~/.aws && chmod 700 ~/.aws
cat >> ~/.aws/credentials <<'EOF'
[lab]
aws_access_key_id = <access key>
aws_secret_access_key = <secret>
EOF
chmod 600 ~/.aws/credentials
```

Confira no passo 5: o `terraform plan` passa sem erro de credencial.

## Passos

1. **Registry.** Abra <https://registry.terraform.io/providers/bpg/proxmox/latest>
   e ache: o *tier* (official, partner ou community), o repositório do código
   e a página do recurso `proxmox_virtual_environment_vm`. A interface é uma
   vitrine de uma API que o `init` consulta:

   ```bash
   curl -s https://registry.terraform.io/v1/providers/bpg/proxmox/versions \
     | jq -r '.versions[].version' | sort -V | tail -5
   terraform providers
   ```

   O `terraform providers` mostra um endereço com três partes. Qual delas você
   não escreveu no `versions.tf`?
2. **Endereço completo.** No `versions.tf`, troque `source = "bpg/proxmox"` por
   `source = "registry.terraform.io/bpg/proxmox"` e rode `terraform init`:
   mudou alguma coisa no lock? Depois troque para `hashicorp/proxmox`, rode
   `terraform init` e leia o erro. Volte para `bpg/proxmox`.
3. **Nome local.** No `required_providers`, renomeie a chave `proxmox` para
   `pve`, e o bloco `provider "proxmox"` para `provider "pve"`. Rode
   `terraform init` e leia o erro: que provider ele foi buscar, e por quê? Para
   consertar sem desfazer o nome, ponha `provider = pve` no recurso e rode
   `terraform init` e `terraform validate`. Depois volte tudo para `proxmox`
   (a convenção é o nome local igual ao prefixo dos recursos).
4. **Configuração por variável de ambiente.** Apague os três argumentos do
   bloco `provider "proxmox"` (deixe o bloco vazio) e as variáveis
   `proxmox_endpoint` e `proxmox_api_token` do `variables.tf` e do tfvars.
   Passe tudo pelo ambiente; o `read -rs` lê o token sem mostrar na tela e sem
   gravar no histórico do shell:

   ```bash
   export PROXMOX_VE_ENDPOINT="https://proxmox.<tailnet>.ts.net:8006"
   export PROXMOX_VE_INSECURE=true
   read -rs PROXMOX_VE_API_TOKEN && export PROXMOX_VE_API_TOKEN
   terraform plan
   ```

   Funciona? Agora apague o bloco `provider "proxmox" {}` inteiro e rode
   `terraform plan` de novo. Por fim, devolva argumentos e variáveis (no lab a
   convenção é o tfvars), troque o token do ambiente por um errado
   (`export PROXMOX_VE_API_TOKEN=errado`) e rode `terraform plan`: quem
   ganhou, o argumento ou o ambiente? Limpe com
   `unset PROXMOX_VE_ENDPOINT PROXMOX_VE_INSECURE PROXMOX_VE_API_TOKEN`.
5. **Um segundo provider (AWS).** No `required_providers`, acrescente
   `aws = { source = "hashicorp/aws", version = "~> 6.0" }`. Num `aws.tf`:
   um bloco `provider "aws"` com `profile = "lab"`, `region = "eu-central-1"`
   e `default_tags { tags = { env = "lab", experimento = "roadmap-04" } }`, e
   um `aws_s3_bucket` `eu` com `bucket_prefix = "lab-roadmap-04-"` (o nome de
   bucket é único no mundo inteiro; o prefixo deixa a AWS completar, e o
   `lab-` é o que a policy do `lab-terraform` permite). Rode `terraform plan`
   antes do init: leia o erro. Depois:

   ```bash
   terraform init        # o provider da AWS tem ~800 MB: demora
   du -sh .terraform/providers/*/*/*
   terraform providers
   grep '^provider' .terraform.lock.hcl
   terraform apply
   terraform state show aws_s3_bucket.eu | grep -A4 tags_all
   ```

   De onde vieram as tags, se o recurso não tem nenhuma?
6. **Duas configurações do mesmo provider (alias).** Acrescente um segundo
   `provider "aws"` igual ao primeiro, mas com `alias = "us"` e
   `region = "us-east-1"`, e um bucket `us` com `provider = aws.us`.
   `terraform apply` e veja de qual configuração cada recurso veio:

   ```bash
   jq -r '.resources[] | "\(.name)  \(.provider)"' terraform.tfstate
   terraform state show aws_s3_bucket.us | grep region
   ```

   Agora apague **o bloco com alias e o bucket `us`** do código, sem destruir
   antes, e rode `terraform plan`: leia o erro. Devolva só o bloco com alias,
   rode `terraform apply` (o bucket `us` é destruído) e só então apague o
   bloco.
7. **Excluir uma versão.** Troque a constraint por
   `version = ">= 0.114, != 0.118.0"` e rode `terraform init`: leia o erro.
   Rode `terraform init -upgrade`: qual versão entrou? Leia o que mudou entre
   ela e a 0.118.0 no
   [CHANGELOG](https://github.com/bpg/terraform-provider-proxmox/blob/main/CHANGELOG.md).
   Volte para `version = "~> 0.114"` e rode `terraform init -upgrade`.
8. **Fechar o ciclo.** `terraform version` (repare que mostra também as
   versões dos providers), `terraform plan` e `terraform apply`. Confira a VM
   990 no Proxmox e o bucket `eu` no console da AWS (região Frankfurt).

## Destruir

```bash
terraform destroy
```

Confira: `terraform state list` vazio, a VM 990 fora do Proxmox e nenhum
bucket `lab-roadmap-04-` no console da AWS (*S3 → General purpose buckets*,
que lista todas as regiões). O lock fica como o passo 8 deixa: `bpg/proxmox`
0.118.0 e `hashicorp/aws` 6.x, só com o hash `h1:` de linux_amd64.
