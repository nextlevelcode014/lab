# 05 — Recursos: comportamento, ciclo de vida e meta-argumentos

O `terraform/` começa com o projeto do tópico 4 sem o bucket: os providers
`proxmox` e `aws` (profile `lab`, `default_tags`) e uma VM `roadmap-05`, VMID
990, desligada. Você acrescenta buckets S3 vazios (não custam nada) para ver
`count` e `for_each`, e usa a VM para o `lifecycle`.

O que está no git é o projeto como o passo 9 deixa; para refazer do começo,
apague o `buckets.tf`, o `terraform_data` e o `depends_on` e `lifecycle` da
VM.

Os meta-argumentos valem para qualquer recurso, de qualquer provider:
`count`, `for_each`, `depends_on`, `provider` e `lifecycle` são do Terraform,
não da AWS nem do Proxmox.

## Antes

Tailscale ligado, o token no tfvars e o profile `lab` da AWS, como no
[tópico 4](../04-providers/README.md):

```bash
cd experimentos/roadmap-terraform/05-recursos/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply      # só a VM 990
```

## Passos

1. **count.** Num `buckets.tf`, uma variável `nomes` (`list(string)`, padrão
   `["a", "b", "c"]`) e um `aws_s3_bucket` `c` com `count = length(var.nomes)`
   e `bucket_prefix = "lab-roadmap-05-${var.nomes[count.index]}-"`. Aplique e
   veja os endereços:

   ```bash
   terraform state list
   ```

2. **O problema do count.** Tire o `"a"` da lista (`["b", "c"]`) e rode
   `terraform plan`. Quantos buckets ele quer destruir e recriar, se você só
   tirou um? Leia o plan com calma (`c[0]`, `c[1]`, `c[2]`) antes de aplicar.
   Aplique.
3. **for_each.** Troque o `count` por `for_each = toset(var.nomes)` e
   `var.nomes[count.index]` por `each.key`. Devolva o `"a"` à lista e rode
   `terraform plan`: até os buckets que não mudaram são recriados. Por quê?
   Aplique e veja os endereços de novo com `terraform state list`. Agora tire o `"a"`
   outra vez e rode `terraform plan`: compare com o passo 2. Aplique.
4. **depends_on.** Ponha `depends_on = [aws_s3_bucket.c]` na VM. Nada na VM
   usa os buckets, então o Terraform não teria como saber dessa ordem:

   ```bash
   terraform graph | grep -E 'proxmox.*->'
   ```

   Rode o comando antes e depois de acrescentar o `depends_on`. Leia a seta: quem
   depende de quem? Aplique (não muda nada na VM: `depends_on` só mexe na
   ordem).
5. **ignore_changes.** Como no tópico 1, edite as *Notes* da VM 990 na
   interface do Proxmox e rode `terraform plan`: ele quer desfazer. Agora, na
   VM:

   ```hcl
   lifecycle {
     ignore_changes = [description]
   }
   ```

   `terraform plan` de novo. Edite outra coisa que está no código, como a
   memória (*Hardware → Memory*), e rode `terraform plan`: o
   `ignore_changes` vale para ela?
6. **replace_triggered_by.** Acrescente um recurso que não cria nada fora do
   Terraform, só guarda um valor no state:

   ```hcl
   resource "terraform_data" "versao" {
     input = "1"
   }
   ```

   No `lifecycle` da VM, `replace_triggered_by = [terraform_data.versao]`.
   Aplique. Depois troque `input = "1"` por `"2"` e rode `terraform plan`: o
   que acontece com a VM, se você não mexeu nela?
7. **create_before_destroy.** No `aws_s3_bucket` `c`, troque o prefixo para
   `"lab-roadmap-05-${each.key}-v2-"` e aplique: repare na ordem no output
   (`Destroying` e `Creation complete`). Agora ponha no bucket:

   ```hcl
   lifecycle {
     create_before_destroy = true
   }
   ```

   Troque para `-v3-` e aplique de novo. Qual veio primeiro desta vez?
8. **prevent_destroy.** No `lifecycle` do bucket, `prevent_destroy = true`.
   Rode `terraform destroy` e leia o erro. Agora apague o bloco
   `aws_s3_bucket` `c` **inteiro** do código e rode `terraform plan`: o que
   aconteceu com a proteção? Devolva o bloco (com `prevent_destroy = false`,
   para conseguir destruir no fim).
9. **provider por recurso.** No tópico 4 o bucket de outra região precisou de
   um alias. A AWS 6.x aceita `region` no próprio recurso: crie um
   `aws_s3_bucket` `us` com `region = "us-east-1"` e
   `bucket_prefix = "lab-roadmap-05-us-"`, **sem** alias, e aplique.

   ```bash
   jq -r '.resources[] | "\(.type).\(.name)  \(.provider)"' terraform.tfstate
   terraform state show aws_s3_bucket.us | grep region
   ```

   Que configuração de provider o bucket `us` usou?

## Destruir

```bash
terraform destroy
```

Confira: `terraform state list` vazio, a VM 990 fora do Proxmox e nenhum
bucket `lab-roadmap-05-` no console da AWS (*S3 → General purpose buckets*,
que lista todas as regiões).
