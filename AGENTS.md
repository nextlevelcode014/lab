# AGENTS.md

Laboratório: Terraform + Ansible **descartáveis**, para testar o que não é a
infra de produção (essa é do repositório `infra`). Pode errar,
destruir e recriar à vontade, **desde que nada aqui alcance a produção**.

Leia também as instruções de [experimentos](experimentos/AGENTS.md) ou de
[módulos compartilhados](modules/AGENTS.md) antes de mexer nessas partes.
Os `AGENTS.md` são a fonte das instruções; `CLAUDE.md` só encaminha para eles.

## Isolamento: a regra que não se quebra

- **Proxmox:** só o token `lab@pve`, com permissão nos VMIDs **900–999**
  (ACL em cada `/vms/<id>`, imposta pelo Proxmox; o módulo `proxmox-vm`
  também valida) e no pool `lab`. Nunca usar o `terraform@pve` da produção,
  nunca dar papel ao `lab@pve` na raiz `/`. Detalhes em `docs/proxmox.md`.
- **Tailscale:** máquina do lab entra com `tag:lab` e auth key efêmera. A ACL
  é do repo `infra` (`ansible/tailscale/policy.hujson`); mudança nela é PR lá.
- **Nuvem:** alerta de custo antes do primeiro `apply`, e todo recurso com
  `env=lab` (`docs/nuvem.md`).
- **Nada de importar roles ou módulos da produção:** copie. Acoplar os repos
  traz de volta o risco que a separação evita.

## Segredos

- Ansible: `vault.yml` na raiz (cifrado, fora do git, template em
  `vault.yml.example`), com senha **própria do lab**, nunca a da produção.
  Playbook que usa segredo o carrega por `vars_files`, e o `ansible.cfg` do
  experimento liga `ask_vault_pass`; sem segredo, nenhum dos dois. Variáveis
  com prefixo `vault_`.
- Auth key do Tailscale que vai no `user_data` (VPS em nuvem): **de uso
  único**, por `TF_VAR_tailscale_authkey`, nunca a reutilizável do vault. O
  `user_data` fica legível no metadata service, ao alcance de qualquer
  container da máquina.
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
  `root@pam` liga. O [lxc-dns](experimentos/lxc-dns/README.md) é a exceção
  documentada para testar um role exclusivo de LXC; não muda essa regra para
  outros experimentos.
- Rede na `vmbr2`, a bridge isolada do lab (ADR 0021 do repo `infra`):
  só sai para a internet, por NAT. IP fixo tirado do VMID (900 →
  `10.60.0.100`), no `modules/proxmox-vm`. Daqui não há rota até ela: o SSH
  e o Ansible saltam pelo Proxmox (`-J root@proxmox` no `ansible.cfg`), e o
  navegador chega pela tailnet depois que o playbook a põe lá, pelo nome
  curto (`http://lab-<app>:<porta>`: `<tailnet>.ts.net` é HSTS). Nunca a `vmbr0`:
  ela é a LAN de onde o notebook estiver.
- DNS da VM por TLS, Quad9 primeiro e Cloudflare de reserva, e
  `--accept-dns=false` no Tailscale (a rede de casa já bloqueou o Quad9
  inteiro, e o DNS da tailnet aponta para o AdGuard do Pi, fora do alcance
  do `tag:lab`). Experimento novo copia as
  duas tasks do playbook do `audiobookshelf`.
- A imagem do Ubuntu e o snippet são colocados à mão, como root
  (`docs/proxmox.md`): o token do lab não tem permissão para isso, de
  propósito.

## Comandos

```bash
cd experimentos/<nome>/terraform && terraform init && terraform plan
cd ../ansible && ansible-playbook playbook.yml
```

Antes de commitar: `terraform fmt -recursive` e `terraform validate` no
experimento com código Terraform alterado. Escolha as verificações conforme
o efeito; uma revisão documental não exige provisionar ambientes.

## Fluxo e evidências

Siga o [contrato de risco e evidências do infra](https://forge.nextlevelcode.pro/nextlevelcode/infra/src/commit/ac72e0a78b42f9c1779dafc578904da16dda4659/docs/fluxo-de-mudanca.md),
na revisão identificada pelo link. Não copie suas regras para este repositório.
Os critérios de uso de `grill-me`, `engineering:debug` e
`engineering:code-review` estão na seção “Uso das skills” desse contrato.
O roadmap aprovado fica no `PLAN.md` local e não rastreado do `infra`; ele
acompanha o andamento, enquanto o contrato e as instruções essenciais estão
versionados. A falta dessa cópia local não dispensa as regras versionadas.

Explique o objetivo e como verificar antes de editar. Use branch e PR no
Forgejo, com `comecar` e `entregar`; o responsável faz o squash merge
manualmente. Registre no PR o código testado, os comandos, os resultados e
os limites. Guias guardam procedimentos; resultados de execução ficam no PR
ou em evidências sanitizadas referenciadas por ele. Instalação de dependências
e operações com efeitos colaterais precisam de autorização prévia.
