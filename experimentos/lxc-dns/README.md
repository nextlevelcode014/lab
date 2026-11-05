# DNS de LXC com Tailscale e rollback real

Experimento reproduzível da etapa 3 do [PR infra #69](https://forge.nextlevelcode.pro/nextlevelcode/infra/pulls/69).
Valida DNS público por DoT, MagicDNS por FQDN/nome curto, reinícios reais,
reboot e rollback com uma carga Docker ativa. O role copiado e seus checksums
estão em [ORIGEM.md](ORIGEM.md).

**Estado: ensaio autorizado executado em 03/11/2026**, com resultados abaixo.
Novas execuções para criar o LXC, instalar pacotes,
cadastrá-lo na tailnet, reiniciar serviços e destruí-lo exigem autorização.
Este experimento é a exceção documentada à preferência por VMs no lab: o role
recusa virtualização diferente de LXC. A exceção não muda os demais experimentos.

| Recurso | Valor |
|---|---|
| LXC unprivileged / pool | `902` / `lab` |
| Nome / rede | `lab-dns-pr69` / `vmbr2`, `10.60.0.102/24`, gateway `10.60.0.1` |
| Capacidade | 2 vCPU, 1 GiB RAM, disco 8 GiB |
| Template | Ubuntu 26.04 já presente em `local` |
| Permissões | token existente `lab@pve`; ACLs existentes |
| Tailscale | auth key efêmera pré-aprovada do vault do lab, `tag:lab` |
| Docker | pacote Ubuntu; `postgres:16-alpine` local, sem pull durante o ensaio |

Não anunciar rotas/exit node nem mudar ACLs, DNS global ou chaves. O peer de
MagicDNS é o desktop de administração, não um serviço de produção. A política
existente permite desktop → lab; confirmar visibilidade do peer antes do ensaio.
Se faltar acesso ou aprovação de dispositivo, parar sem ampliar permissões.

## Arquivos e estado

- `terraform/`: state **local próprio**, inventário `ansible_host` e providers
  fixados. Não contém backend de produção nem importa módulos dela.
- `ansible/preparar.yml`: instala serviços e cria baseline funcional; não reaplicar
  depois do snapshot. Usa o vault existente da raiz do lab.
- `ansible/playbook.yml`: aplica somente o role DNS copiado, sem carregar vault.
- `scripts/`: contexto privado e verificações reais; os testes offline do role
  ficam em `ansible/roles/lxc_dns/tests/`.

Versionar código, lock e instruções. Não versionar `terraform.tfvars`, state,
planos `*.tfplan`, `.private/`, vault ou logs privados. Conservar o state neste
diretório até destruir o LXC: perder o state não apaga o recurso no Proxmox.
O Ansible usa o inventário lido desse state; não tem um state equivalente próprio.
Não mover para cá o plano/state temporário preparado anteriormente em `/tmp`:
nenhum recurso foi criado por ele. Gerar o plano novamente neste experimento.

## Preparar os acessos

São pré-requisitos as ferramentas/collections já usadas no lab: Terraform,
Ansible, `cloud.terraform` e `artis3n.tailscale`. Não instalar dependências sem
aprovação. O host Proxmox precisa ter template Ubuntu 26.04 e `vmbr2` já prontos.

1. Configurar valores locais, a partir de `experimentos/lxc-dns/terraform`:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Preencher endpoint, token **do lab** e chave SSH pública existente do lab.
   Confira: `lab@pve!` é validado; token de produção é recusado. Os valores
   reais ficam fora do Git. É manual porque seleciona credenciais do lab.

2. Conferir o vault existente (`../../vault.yml` a partir deste experimento):
   ele precisa conter `vault_tailscale_authkey`, conforme
   [Tailscale do lab](../../docs/tailscale.md). Não criar/rotacionar chave para
   este ensaio se a chave efêmera e pré-aprovada do lab já estiver válida.
   A senha é a do lab, nunca a da produção. Confira no console que o cadastro
   resultou em `tag:lab` e Ephemeral; não publicar a chave ou a saída privada.
   A confirmação é manual porque o console é a referência do cadastro.

3. No desktop de administração, de dentro deste experimento:

   ```bash
   python3 scripts/contexto.py
   ```

   Confira: `.private/contexto.json` existe com modo 600. Contém apenas o
   FQDN/IP do desktop para verificar a resposta MagicDNS; não publicar.
   A seleção é manual porque o peer precisa ser um desktop já autorizado.

## Criar o LXC (com autorização)

De `terraform/`:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=ensaio.tfplan
```

Confira: apenas `proxmox_virtual_environment_container.dns_test` e
`ansible_host.dns_test` novos; VMID 902, pool lab e vmbr2. Nenhuma alteração ou
destruição. Verifique que o VMID continua livre antes de aplicar:

```bash
ssh root@proxmox 'test ! -e /etc/pve/lxc/902.conf && test ! -e /etc/pve/qemu-server/902.conf'
terraform apply ensaio.tfplan
```

Confira: LXC criado **parado**. Aplicar somente no 902 as flags reservadas ao root:

```bash
ssh root@proxmox 'test "$(pct config 902 | sed -n "s/^hostname: //p")" = lab-dns-pr69 && pct set 902 --features nesting=1,keyctl=1 && pct set 902 --dev0 /dev/net/tun && pct start 902'
```

Confira: `pct config 902` mostra keyctl/nesting e TUN; `pct status 902` mostra
running. É manual porque o Proxmox reserva essas opções ao root; não dar mais
permissões ao token. Terraform ignora essas flags e o estado started para não
desfazer o que foi aplicado fora dele. Nenhum comando mira outro VMID.

## Preparar baseline, carga e snapshot

De `ansible/`:

```bash
ansible-inventory --graph lxc_dns_test
ANSIBLE_CONFIG=ansible-segredos.cfg ansible-playbook preparar.yml
```

Confira: único host `lab-dns-pr69`. A preparação cadastra o nó usando o vault
existente, sem aceitar DNS global, e instala Docker apenas no LXC. Baseline:
Cloudflare por DoT em eth0 e MagicDNS global nos drop-ins `50-lab-baseline.conf`;
Docker com `data-root=/srv/docker-pr69`, opções de logs e DNS `1.1.1.1`.
Esses arquivos 50 pertencem ao ensaio; o role gerencia seus próprios arquivos 60.
Se o cadastro ficar pendente ou o peer não resolver, parar antes do snapshot.

Para os próximos comandos, volte à raiz deste experimento e defina o acesso
pela bridge, independente do Tailscale do LXC:

```bash
lab_ssh() { ssh -i ~/.ssh/lab.pub -o IdentitiesOnly=yes -J root@proxmox root@10.60.0.102 "$@"; }
```

Conferir a host key no primeiro acesso. Se recriar o LXC, conferir a nova chave
pelo console antes de remover a entrada antiga do `known_hosts`. É manual porque
SSH não deve aceitar silenciosamente a troca de identidade.

Copiar **somente a imagem**, sem volumes/configurações, do pi-lab já preparado:

```bash
ssh root@10.50.0.203 docker image save postgres:16-alpine | lab_ssh docker image load
lab_ssh 'docker run -d --name dns-pr69-workload --restart unless-stopped -e POSTGRES_PASSWORD=senha-descartavel-do-lab postgres:16-alpine'
lab_ssh 'for tentativa in $(seq 1 30); do docker exec dns-pr69-workload pg_isready -U postgres && exit 0; sleep 2; done; exit 1'
lab_ssh 'docker exec dns-pr69-workload psql -U postgres -c "CREATE TABLE sentinela (valor text); INSERT INTO sentinela VALUES ('"'"'pr69'"'"');"'
```

Confira: Postgres ready, sem porta publicada; somente dados descartáveis.
É manual porque cria carga no LXC e pressupõe a imagem já presente no pi-lab.
Se a imagem não existir, parar; download exige autorização própria.

Enviar utilitário, verificações e contexto pelo SSH da bridge:

```bash
lab_ssh 'umask 077; cat > /root/lxc-dns-estado-pr69.py' < ansible/roles/lxc_dns/files/estado.py
lab_ssh 'umask 077; cat > /root/pr69-validar.py' < scripts/validar.py
lab_ssh 'umask 077; cat > /root/pr69-reiniciar.py' < scripts/reiniciar.py
lab_ssh 'umask 077; cat > /root/pr69-contexto.json' < .private/contexto.json
lab_ssh 'python3 /root/pr69-validar.py registrar'
lab_ssh 'python3 /root/lxc-dns-estado-pr69.py salvar /root/antes-pr69-tailnet'
lab_ssh 'stat -c "%a %U" /root/antes-pr69-tailnet /root/antes-pr69-tailnet/estado.json'
```

Confira: baseline aprovado, diretório 700/root e manifesto 600/root. O registro
recusa sobrescrever o baseline. Os serviços precisam estar ativos; guarda hashes,
gateway, identidade Tailscale, preferências, estados das units e ID do workload.
Snapshot é de arquivos/units, não disco Proxmox. É manual para fixar a referência.

## Aplicar e testar

De `ansible/`:

```bash
ansible-playbook playbook.yml --check --diff
ansible-playbook playbook.yml
ansible-playbook playbook.yml
```

Confira: somente o alvo de teste, nenhuma falha e última execução `changed=0`.
MagicDNS é habilitado explicitamente mesmo com o grupo staging. O domínio é
lido do nó e tratado com no_log, sem valor real no inventário versionado.
A configuração Docker deve mudar apenas DNS; reinício do daemon é esperado.

Na raiz do experimento, mantendo a função `lab_ssh`:

```bash
lab_ssh 'python3 /root/pr69-validar.py novo'
lab_ssh 'python3 /root/pr69-reiniciar.py tailscaled'
lab_ssh 'python3 /root/pr69-reiniciar.py systemd-resolved'
lab_ssh 'cat /proc/sys/kernel/random/boot_id'
ssh root@proxmox 'pct reboot 902'
```

Confira: público por eth0; MagicDNS por FQDN/nome curto com IP esperado no host
e em **novos** containers sem DNS explícito. Serviços ativos, identidade e
opções Docker preservadas, mesmo workload e sentinela SQL. A carga pode levar
alguns segundos para voltar ready após restart/reboot; repetir a verificação
quando pronta e registrar a indisponibilidade, sem chamar uma falha de aprovada.
`reiniciar.py` registra separadamente cada resultado imediato, inclusive falhas,
e exige a matriz completa após 15 segundos. O retorno de `systemctl restart`
não garante que o Tailscale já esteja em Running; uma observação imediata falsa
não é registrada como aprovada. O helper verifica o alvo e só aceita os dois
serviços do ensaio. Os passos são manuais porque interrompem serviços ou o LXC.

Depois que o SSH voltar, repetir imediatamente e após 15 segundos:

```bash
lab_ssh 'cat /proc/sys/kernel/random/boot_id; python3 /root/pr69-validar.py novo'
sleep 15
lab_ssh 'python3 /root/pr69-validar.py novo'
cd ansible
ansible-playbook playbook.yml
```

Confira: boot_id mudou; verificações aprovadas e reaplicação `changed=0`.
Para repetir a sondagem autenticada dos provedores, da raiz do experimento:

```bash
lab_ssh python3 - < ansible/roles/lxc_dns/tests/provedores.py
```

Confira: 3/3 sucessos UDP e DoT em cada provedor. Essa sondagem direta é
somente de leitura; não mede failover do resolved nem modifica provedores.

## Rollback completo com serviços ativos

Na raiz do experimento, pela bridge:

```bash
lab_ssh 'python3 /root/pr69-validar.py novo && systemctl show docker -p InvocationID --value > /root/pr69-docker-antes-rollback'
lab_ssh 'python3 /root/lxc-dns-estado-pr69.py restaurar /root/antes-pr69-tailnet'
lab_ssh 'python3 /root/pr69-validar.py rollback'
```

Confira: arquivos, links, modos, ownership e ausências iguais ao snapshot;
configuração Docker original inteira; Docker realmente reiniciou, workload com
mesmo ID e sentinela preservada. Tailscaled/resolved/Docker e seus estados de
habilitação voltam ao baseline. DNS público e MagicDNS do host funcionam.
No baseline o Docker tinha DNS público explícito, portanto o teste pós-rollback
exige DNS público no container; MagicDNS no Docker é critério da fase `novo`.
É manual porque reconfigura a rede e reinicia serviços. Se o SSH falhar, usar
`ssh root@proxmox 'pct exec 902 -- python3 /root/lxc-dns-estado-pr69.py restaurar /root/antes-pr69-tailnet'`.

Não aprovar só pela igualdade de arquivos. Depois do rollback, deixar o LXC
no baseline para inspeção; não reaplicar `preparar.yml` por cima do snapshot.
O ensaio não cobre restauração de uma versão antiga com timer MagicDNS ativo,
pois ela não existe no baseline deste LXC novo.

## Evidências e destruição

Registrar resultados sanitizados no PR/runbook do infra, com o commit do role
em ORIGEM.md. Logs privados, snapshots e contexto não vão ao Git. O procedimento acima
é reproduzível; os resultados desta execução estão registrados abaixo.

Com autorização de limpeza, de `terraform/`:

```bash
terraform plan -destroy -out=limpeza.tfplan
terraform apply limpeza.tfplan
terraform state list
ssh root@proxmox 'test ! -e /etc/pve/lxc/902.conf'
```

Confira: plano destrói somente o LXC 902 e seu `ansible_host`; state vazio e
configuração ausente. É manual porque apaga o disco de teste. O nó efêmero
some conforme o ciclo do Tailscale; se precisar removê-lo no console, solicitar
explicitamente essa ação, sem revogar a chave compartilhada do lab.

## Checks offline

De `ansible/`, sem aplicar playbooks nem usar o vault:

```bash
python3 -m unittest discover -s roles/lxc_dns/tests -p 'test_*.py' -v
python3 roles/lxc_dns/tests/integracao.py
```

Confira: código zero. Integração requer as ferramentas/namespaces descritos
no teste; não instalar dependências automaticamente. Esses checks não substituem
o ensaio real de Tailscale, Docker, reboot ou rollback acima.

## Resultado de 03/11/2026

Role de `infra@5a4627f`, cópia descrita em ORIGEM.md; Ubuntu 26.04,
systemd `259.5-0ubuntu3`, Tailscale `1.104.5`, Docker `29.1.3`.
O token e a auth key foram os existentes do lab; não houve troca de chaves,
ACLs ou DNS global. O arquivo temporário de senha do vault foi removido.

| Verificação | Resultado |
|---|---|
| Provisionamento | Apenas LXC 902 e seu inventário criados no state próprio; TUN/keyctl somente nele |
| Baseline e snapshot | Público, MagicDNS FQDN/curto e sentinela SQL aprovados; snapshot 700/root e manifesto 600/root |
| Check/diff e aplicação | `changed=6` e `changed=7`, respectivamente; zero falhas ou hosts inalcançáveis |
| Reaplicação | `changed=0` antes e depois do reboot, sem handlers |
| Público e MagicDNS | Aprovados no host e em novos containers Docker na bridge padrão, sem DNS explícito |
| Restart tailscaled | Checagem imediata inicial falhou; diagnóstico e recuperação descritos abaixo |
| Restart resolved | Verificações imediatas e matriz completa após 15 s aprovadas |
| Reboot Proxmox | boot_id novo, matriz imediata e após 15 s aprovada; stub, marker e DoT obrigatório preservados |
| Provedores | DNS4EU e Cloudflare com 3/3 sucessos UDP e 3/3 DoT autenticado por CA/SNI, por provedor |
| Rollback com carga ativa | Arquivos/links/modos/ownership/ausências iguais ao snapshot; Docker original restaurado e InvocationID mudou |
| Serviços e dados | Estados de habilitação/atividade e identidade Tailscale preservados; mesmo container e sentinela SQL após rollback |

A primeira chamada ao validador completo imediatamente após o restart de
tailscaled terminou com `CalledProcessError`. Uma verificação posterior passou;
no restart repetido com diagnóstico, o estado ainda não era Running aos 0,042 s,
o público respondeu aos 0,410 s e o MagicDNS FQDN respondeu aos 5,420 s.
A matriz completa iniciada após 15 s passou. São observações desta rede,
sem garantia de tempo ou ausência de interrupção. O helper foi acrescentado
para preservar essa distinção entre startup e recuperação; o role não mudou.

As sondagens DoT com conexão nova tiveram medianas de 772,5 ms no DNS4EU e
90,7 ms na Cloudflare. Não representam cache ou conexão persistente e não
alteram a escolha de provedores do PR infra #69 (acompanhamento na issue infra #71).

Após o rollback, o LXC continua ativo com o baseline: Cloudflare por DoT no
host, MagicDNS global, Docker com DNS explícito `1.1.1.1` e workload preservado.
MagicDNS no Docker foi validado na fase `novo`; não é esperado nesse baseline
com DNS público explícito. Não foi executada limpeza/destroy.

O ensaio não aplicou configuração nos LXCs de produção ou no Pi físico.
O complemento abaixo cobre as instalações legadas auditadas. Desligamento
dos hosts físicos continua fora deste ensaio. O acesso do ensaio usou a bridge e um
known_hosts privado, obtido do LXC pelo console Proxmox, inclusive no rollback.

## Complemento: estados atuais de produção

A auditoria dos três LXCs identificou dois perfis distintos, descritos e
rastreáveis em [LEGADO.md](LEGADO.md): Caddy com script/timer (`timer`),
Forgejo e Vaultwarden com oneshot active/exited sem timer (`oneshot`). O
baseline novo do primeiro ensaio não substitui esses testes de migração.

A inspeção pode ser repetida, somente por leitura, sem exportar arquivos
completos. Da raiz deste experimento, com a sessão SSH do Proxmox autorizada:

```bash
mkdir -p .private/producao
ssh root@10.50.0.200 python3 - < scripts/auditar-legado.py > .private/producao/caddy-metadados.json
ssh root@10.50.0.201 python3 - < scripts/auditar-legado.py > .private/producao/forgejo-metadados.json
ssh root@10.50.0.202 python3 - < scripts/auditar-legado.py > .private/producao/vaultwarden-metadados.json
```

Confira os perfis e hashes antes de usar as fixtures:

```bash
python3 scripts/conferir-auditoria.py
```

Confira: três perfis auditados aprovados, sem exportar arquivos completos; os
relatórios contêm hashes/metadados, estados/vínculos e campos DNS sanitizados; nenhuma credencial ou configuração completa transferida. Não
publicar os arquivos de auditoria. É manual porque os alvos de produção só
podem ser inspecionados dentro do escopo autorizado. Se o SSH exigir check,
concluir a autenticação solicitada pelo Tailscale; não alterar ACLs/chaves.

Executar este complemento com o baseline e a carga originais já preparados,
incluindo `/root/antes-pr69-tailnet` e `/root/pr69-baseline.json`.
O código histórico dos perfis fica em `legado/`. Enviar para o 902 pela
função `lab_ssh` descrita anteriormente:

```bash
tar -cf - -C legado . | lab_ssh 'umask 077; mkdir -p /root/pr69-legado; tar -xf - -C /root/pr69-legado'
lab_ssh 'umask 077; cat > /root/pr69-legado.py' < scripts/legado.py
lab_ssh 'python3 /root/pr69-legado.py preparar timer'
```

Confira: baseline legado funcional no host/Docker e snapshot próprio em
`/root/antes-legado-timer`. A preparação guarda os drop-ins 50 originais à
parte, instala o DNS global legado, script/timer e vínculos reais; o Docker
mantém a carga e recebe o mesmo DNS da produção. O snapshot original do
primeiro ensaio não é sobrescrito. É manual porque altera o cenário do 902
e reinicia resolved/Docker; não executar em outro host.

De `ansible/`, migrar e reaplicar:

```bash
ansible-playbook playbook.yml --check --diff
ansible-playbook playbook.yml
ansible-playbook playbook.yml
```

Confira: migração remove units/script/vínculos, ativa o desenho novo e
reaplicação termina em `changed=0`. Na raiz do experimento:

```bash
lab_ssh 'python3 /root/pr69-legado.py novo timer'
lab_ssh 'systemctl restart tailscaled; sleep 15; python3 /root/pr69-legado.py novo timer'
lab_ssh 'systemctl restart systemd-resolved; sleep 15; python3 /root/pr69-legado.py novo timer'
lab_ssh 'cat /proc/sys/kernel/random/boot_id'
ssh root@proxmox 'pct reboot 902'
```

Depois do retorno do SSH e da estabilização dos serviços:

```bash
lab_ssh 'cat /proc/sys/kernel/random/boot_id; python3 /root/pr69-legado.py novo timer'
```

Confira: boot_id mudou; público por eth0 com os dois provedores e DoT,
MagicDNS FQDN/curto no host e em Docker, configuração/identidade e a mesma
carga/sentinela SQL preservadas. Reaplicar em `ansible/` e exigir `changed=0`.
Os reinícios e reboot são manuais por interromperem o LXC de teste.

Executar o rollback com a carga ativa:

```bash
lab_ssh 'systemctl show docker -p InvocationID --value > /root/pr69-docker-rollback-timer; python3 /root/lxc-dns-estado-pr69.py restaurar /root/antes-legado-timer'
lab_ssh 'python3 /root/pr69-legado.py rollback timer'
```

Confira: arquivos/modos/ownership/links/ausências e vínculos de habilitação
iguais aos registrados; timer ativo e executando novamente o script, DNS
funcional no host/Docker e sentinela preservada. O validador observa uma nova
execução real do timer, não apenas sua presença. É manual porque restaura a
configuração anterior e reinicia serviços.

Repetir a sequência completa para `oneshot`, começando por:

```bash
lab_ssh 'python3 /root/pr69-legado.py preparar oneshot'
```

Substituir `timer` por `oneshot` nas validações e no arquivo de InvocationID, e usar o snapshot
`/root/antes-legado-oneshot` no rollback. Confira: unit volta active/exited,
com os três vínculos originais, sem criar timer ou script inexistentes no
perfil de Forgejo/Vaultwarden. Não habilitar timers só para fazer o teste passar.

Ao concluir ambos os perfis, restaurar o baseline original do laboratório:

```bash
lab_ssh 'python3 /root/pr69-legado.py limpar'
```

Confira: drop-ins 50 originais e snapshot `/root/antes-pr69-tailnet`
restaurados, integração legada retirada somente do 902 e validação original
de rollback aprovada. Os snapshots de cada perfil ficam guardados para inspeção.
Não há aplicação de configuração em produção nem destroy nesta sequência.


### Resultado do complemento em 03/11/2026

As fixtures foram conferidas por `scripts/conferir-auditoria.py` contra os
metadados sanitizados dos três hosts: Caddy → timer; Forgejo/Vaultwarden →
oneshot. O resolved.conf legado coincide por SHA-256 nos três; units/script
coincidem após normalização do domínio. O código veio do histórico Git.

| Verificação | Perfil timer (Caddy) | Perfil oneshot (Forgejo/Vaultwarden) |
|---|---|---|
| Baseline real e snapshot independente | Aprovados | Aprovados |
| Check/diff / aplicação | `changed=4` / `changed=6`, zero falhas | `changed=4` / `changed=6`, zero falhas |
| Reaplicações antes/depois de reboot | `changed=0`, sem handlers | `changed=0`, sem handlers |
| DNS público e MagicDNS FQDN/curto no host/Docker | Aprovados | Aprovados |
| Após restart real de tailscaled/resolved | Aprovados após estabilização de 15 s | Aprovados após estabilização de 15 s |
| Reboot pelo Proxmox | boot_id novo; matriz aprovada | boot_id novo; matriz aprovada |
| Rollback exato de arquivos e vínculos | Quatro vínculos, script e timer restaurados | Três vínculos, unit ativa; timer/script continuam ausentes |
| Integração antiga em funcionamento | Timer executou novamente o script com sucesso | Unit voltou active/exited, ExecMainStatus=0 |
| Dados e configuração | Mesmo container, sentinela SQL, identidade, rede e daemon.json | Mesmo container, sentinela SQL, identidade, rede e daemon.json |

A migração removeu os artefatos e vínculos de cada perfil sem reconciliação
legada remanescente. O rollback usou o utilitário atual sem correção no role:
além dos arquivos, foram conferidos estados enabled/active e funcionamento
real do DNS. Docker não foi reiniciado na migração/rollback destes perfis,
pois já usavam `172.17.0.1`; o InvocationID permaneceu igual no rollback.
O primeiro ensaio acima cobre o caso complementar em que o DNS do daemon
muda e exige restart real, com a sentinela também preservada.

O 902 voltou ao baseline original com `legado.py limpar`, e o validador
original aprovou a restauração. Snapshots por perfil e evidências privadas
foram preservados. Produção recebeu somente inspeções de leitura.
A matriz cobre os dois estados distintos encontrados nos três alvos, usando
nome, IP, identidade, credenciais e carga de teste do lab; não replica dados
ou aplicações de produção. Antes do rollout, repetir a auditoria e parar
se os estados divergirem dos perfis cobertos. Desligamentos físicos e as
melhorias das issues infra #72–#74 permanecem fora do PR #69.
