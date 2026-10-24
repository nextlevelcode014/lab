# 01 — Introdução: o ciclo da IaC

Uma VM **vazia e desligada** (VMID 990, sem disco de sistema, sem rede): o
objetivo não é a VM, é ver o Terraform comparar o código com o que existe e
aplicar só a diferença.

## Antes

1. Tailscale ligado (o endpoint do Proxmox é o nome da tailnet):

   ```bash
   tailscale status | head -3
   ```

2. Token do lab no tfvars. Não é automatizável: o segredo está no Vaultwarden.

   ```bash
   cd experimentos/roadmap-terraform/01-introducao/terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

   Cole a string inteira `lab@pve!terraform=<UUID>` em `proxmox_api_token`.

## Passos

1. **Instalação.** `terraform version` mostra `v1.15` ou mais novo. O
   `required_version` do `versions.tf` é o que barra um binário velho.
2. **init.** `terraform init` baixa o provider para `.terraform/` e grava a
   versão exata no `.terraform.lock.hcl` (que vai para o git).
3. **plan.** `terraform plan`. Leia: `+` cria, `~` muda no lugar, `-/+`
   destrói e recria, `-` destrói. Repare no que aparece sem você ter escrito
   (padrões do provider e valores `(known after apply)`).
4. **apply.** `terraform apply`, responda `yes`. Confira na interface do
   Proxmox: VM `990 (roadmap-01)` no pool `lab`, desligada.
5. **Idempotência.** `terraform apply` de novo: `No changes`.
6. **Mudança no código.** Troque `dedicated = 512` por `1024` no `main.tf` e
   rode `terraform plan`: um `~` só no `memory`. Aplique.
7. **Drift.** Na interface do Proxmox, edite as *Notes* da VM 990 (é a
   `description`) e salve. `terraform plan`: o Terraform quer desfazer a sua
   mudança manual. Aplique.
8. **Recriação.** Troque `vm_id = 990` por `991` e rode `terraform plan`:
   `-/+` e `forces replacement`. Aplique.

## Destruir

```bash
terraform destroy
```

Confira: `terraform state list` não mostra nada e a VM 991 sumiu do Proxmox.
