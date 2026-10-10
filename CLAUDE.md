# CLAUDE.md

Laboratório: Terraform + Ansible **descartáveis**, para testar o que não é a
infra de produção (essa é dos repos `terraform` e `ansible`). Pode errar,
destruir e recriar à vontade, **desde que nada aqui alcance a produção**.

## Isolamento: a regra que não se quebra

- **Proxmox:** só o token `lab@pve`, preso ao pool `lab`. VMID **900–999**
  (o módulo `proxmox-vm` valida). Nunca usar o `terraform@pve` da produção,
  nunca dar papel ao `lab@pve` na raiz `/`. Detalhes em `docs/proxmox.md`.
- **Tailscale:** máquina do lab entra com `tag:lab` e auth key efêmera. A ACL
  é do repo `ansible` (`tailscale/policy.hujson`); mudança nela é PR lá.
- **Nuvem:** alerta de custo antes do primeiro `apply`, e todo recurso com
  `env=lab` (`docs/nuvem.md`).
- **Nada de importar roles ou módulos da produção:** copie. Acoplar os repos
  traz de volta o risco que a separação evita.

## Segredos

- Ansible: `vault.yml` na raiz (cifrado, fora do git, template em
  `vault.yml.example`), com senha **própria do lab**, nunca a da produção.
  Cada playbook o carrega por `vars_files`; o `ansible.cfg` do experimento
  liga `ask_vault_pass`. Variáveis com prefixo `vault_`.
- Terraform: `terraform.tfvars` de cada experimento (fora do git).

## Estrutura

Um diretório por experimento em `experimentos/<nome>/`, cada um com:

- `terraform/`: **state próprio** (destruir um nunca toca outro), versões
  dos providers no `versions.tf`, segredos no `terraform.tfvars` (fora do
  git) com um `terraform.tfvars.example` versionado;
- `ansible/`: inventário pelo plugin `cloud.terraform` lendo
  `../terraform`; rode o `ansible-playbook` de dentro de `ansible/`;
- `README.md`: o que testa, como subir, **como conferir** e como destruir.

O que se repete entre experimentos vira módulo em `modules/`. Experimento
novo entra na tabela do `README.md` da raiz.

## Proxmox

- VM, não LXC, para Docker: LXC com Docker precisa de `keyctl`, que só o
  `root@pam` liga.
- Rede por DHCP na `vmbr0`; o IP vem do qemu-guest-agent (instalado pelo
  snippet `local:snippets/lab-vendor.yaml`). Por isso o `agent` fica ligado
  e o primeiro acesso é pela LAN.
- A imagem do Ubuntu e o snippet são colocados à mão, como root
  (`docs/proxmox.md`): o token do lab não tem permissão para isso, de
  propósito.

## Comandos

```bash
cd experimentos/<nome>/terraform && terraform init && terraform plan
cd ../ansible && ansible-playbook playbook.yml
```

Antes de commitar: `terraform fmt -recursive` e `terraform validate` no
experimento mexido.
