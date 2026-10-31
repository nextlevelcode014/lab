# lab

Laboratório da NextLevelCode: Terraform e Ansible para testar coisas que **não
são a infra de produção** (essa mora nos repos `terraform` e `ansible`). Aqui
tudo é descartável: cada experimento sobe, é testado e é destruído.

## Regra de ouro: o lab não alcança a produção

Separar o código é fácil; o que protege é separar o **acesso**:

| Onde | Isolamento |
|---|---|
| Proxmox | usuário `lab@pve` com permissão só no pool `lab`, VMID **900–999** e a bridge `vmbr2`, que só sai para a internet ([docs/proxmox.md](docs/proxmox.md)) |
| Tailscale | nós com `tag:lab`, auth key efêmera; a ACL não deixa `tag:lab` alcançar nada da infra ([docs/tailscale.md](docs/tailscale.md)) |
| Hetzner | projeto `lab` com token próprio: não enxerga o projeto da produção ([docs/nuvem.md](docs/nuvem.md)) |
| AWS / Google | alerta de custo criado **antes** do primeiro `apply`; todo recurso com `env=lab` ([docs/nuvem.md](docs/nuvem.md)) |

## Estrutura

```
experimentos/<nome>/
├── terraform/    state próprio: destruir um experimento nunca toca outro
├── ansible/      configura o que o terraform criou (inventário lido do state)
└── README.md     o que é, como subir, como conferir, como destruir
modules/          módulos Terraform reaproveitados entre experimentos
```

Roles e módulos da produção **não** são importados: copie o que precisar.
Acoplar os repos traria de volta o risco que a separação existe para evitar.

## Experimentos

| Experimento | Onde | O que testa |
|---|---|---|
| [coolify](experimentos/coolify/README.md) | Proxmox (VM 900) | Coolify como PaaS self-hosted |
| [coolify-hetzner](experimentos/coolify-hetzner/README.md) | Hetzner (cx23, projeto lab) | Coolify com IP público: deploy de site e TLS |
| [audiobookshelf](experimentos/audiobookshelf/README.md) | Proxmox (VM 901) | Audiobookshelf: biblioteca, app no celular e backup que volta |
| [roadmap-terraform](experimentos/roadmap-terraform/README.md) | Proxmox (VMs 990–999) | Exercícios do roadmap.sh de Terraform, um por tópico |
