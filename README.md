# lab

Laboratório da NextLevelCode: Terraform e Ansible para testar coisas que **não
são a infra de produção** (essa mora no repo `infra`). Aqui
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

## Fluxo de mudança

As instruções dos agentes estão no [AGENTS.md](AGENTS.md), com orientações
para [experimentos](experimentos/AGENTS.md) e [módulos](modules/AGENTS.md).
O [contrato comum de risco e evidências](https://forge.nextlevelcode.pro/nextlevelcode/infra/src/commit/ac72e0a78b42f9c1779dafc578904da16dda4659/docs/fluxo-de-mudanca.md)
define como registrar a reprodução, o código testado e os limites de um ensaio.
Mudanças passam por branch, PR e squash merge manual pelo responsável.

O andamento do roadmap aprovado é acompanhado no `PLAN.md` local do `infra`,
mantido fora do Git por orientação do responsável. As regras necessárias
para trabalhar neste repositório estão nos arquivos versionados acima.

## Experimentos

| Experimento | Onde | O que testa |
|---|---|---|
| [lxc-dns](experimentos/lxc-dns/README.md) | Proxmox (LXC 902) | DNS público, MagicDNS, persistência e rollback com Docker; execução depende de autorização |
| [coolify](experimentos/coolify/README.md) | Proxmox (VM 900) | Coolify como PaaS self-hosted |
| [coolify-hetzner](experimentos/coolify-hetzner/README.md) | Hetzner (cx23, projeto lab) | Coolify com IP público: deploy de site e TLS |
| [audiobookshelf](experimentos/audiobookshelf/README.md) | Proxmox (VM 901) | Audiobookshelf: biblioteca, app no celular e backup que volta |
| [andbible](experimentos/andbible/README.md) | Proxmox (LXC 903) | Sincronização WebDAV por HTTPS em dois aparelhos |
| [roadmap-terraform](experimentos/roadmap-terraform/README.md) | Local ou Proxmox (VMs 990–999) | Exercícios do roadmap.sh de Terraform, um por tópico |
