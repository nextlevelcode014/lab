# Docker Mailserver no lab

O ensaio acompanha uma mensagem de `ana@example.test` até a caixa de
`bruno@example.test`, e depois verifica a mesma mensagem em um container
restaurado. Ele serve de preparação para a
[issue do Docker Mailserver no infra](https://forge.nextlevelcode.pro/nextlevelcode/infra/issues/85).

A VM 903 usa o pool `lab` e a bridge `vmbr2`. O Ansible chega por SSH via
Proxmox. O Compose reserva `172.30.85.2` para o servidor numa rede interna,
sem rota externa nem portas publicadas na VM. O cliente roda na própria VM e
se conecta a esse IP. Ele confia explicitamente no certificado autoassinado
do ensaio e valida o IP no SAN. O certificado vale 30 dias.

O SMTP autenticado usa STARTTLS em 587. O IMAP usa TLS desde o início em
993. O ensaio cobre a entrega local, a leitura do conteúdo e a recuperação
da caixa com backup em tar. A validação de DNS público, porta 25 da Hetzner,
entrega externa e Borg fica para os respectivos ensaios.

## 1. Criar e preparar a VM

Confirme a disponibilidade do VMID 903 no pool `lab` e os pré-requisitos do
[Proxmox](../../docs/proxmox.md). A imagem do Ubuntu e o snippet são preparados
no host porque o token do lab só tem acesso de leitura a esses artefatos.
Use o token `lab@pve` e a chave SSH do lab. O `apply` cria uma VM com
2 vCPUs, 2 GiB de RAM e disco de 20 GiB. O playbook instala Docker, Compose e
OpenSSL dentro da VM e gera o certificado de teste.

De `experimentos/docker-mailserver/terraform`:

```bash
cp -n terraform.tfvars.example terraform.tfvars
${EDITOR:-vi} terraform.tfvars
terraform init
terraform plan -out=mailserver.tfplan
terraform show mailserver.tfplan
```

Confira que o plano só cria a VM 903 na `vmbr2` e o recurso do inventário
Ansible. Mantenha o plano e o arquivo de variáveis fora do Git.

```bash
terraform apply mailserver.tfplan
terraform output -raw ip
```

Confira o IP `10.60.0.103`. De `experimentos/docker-mailserver/ansible`:

```bash
ssh root@proxmox true
ansible-playbook playbook.yml --limit lab-docker-mailserver
ssh -J root@proxmox lab@10.60.0.103
```

O primeiro SSH atende à checagem de acesso do salto. Confira que o
playbook terminou com `failed=0` para `lab-docker-mailserver`.

## 2. Enviar e ler a mensagem

Na VM, use uma sessão administrativa para acessar o Docker e os dados.

```bash
sudo -i
cd /srv/docker-mailserver
docker compose pull
docker compose run --rm --no-deps --entrypoint setup mailserver email add ana@example.test
docker compose run --rm --no-deps --entrypoint setup mailserver email add bruno@example.test
docker compose up -d
docker compose logs --tail 50 mailserver
```

Crie as duas contas uma vez. Escolha senhas só para este ensaio nos prompts
do `setup`. Os prompts evitam que as senhas entrem no histórico de comandos.
O DMS persiste os hashes no volume de configuração. Confira pelos logs que
Postfix e Dovecot subiram. [Guia de contas do Docker Mailserver](https://docker-mailserver.github.io/docker-mailserver/latest/config/account-management/provisioner/file/)

Valide a rede e o certificado da instância.

```bash
docker network inspect docker-mailserver_correio --format '{{.Internal}}'
docker inspect "$(docker compose ps -q mailserver)" --format '{{json .HostConfig.PortBindings}}'
openssl x509 -in dados/tls/mail.crt -noout -checkhost mail.example.test
```

O primeiro comando retorna `true`, o segundo mostra um mapa de portas vazio
ou `null` e o terceiro confirma o nome no certificado.

```bash
id_mensagem=$(python3 testar.py enviar)
python3 testar.py conferir "$id_mensagem"
```

Use as senhas de Ana e Bruno quando solicitadas. O primeiro comando registra
o `Message-ID` da mensagem aceita pelo SMTP. O segundo valida o certificado
na conexão IMAP e confirma o remetente, destinatário e corpo da mensagem.
Guarde o ID e use a mesma sessão no próximo passo.

## 3. Recuperar a caixa em uma instância limpa

Ainda na VM, de `/srv/docker-mailserver`, confira a fila antes de parar o
servidor. Com o ensaio entregue, `postqueue -p` deve indicar fila vazia.

```bash
docker compose exec -T mailserver postqueue -p
```

Pare a instância antes de copiar os arquivos para obter uma cópia sem
escritas concorrentes. Use outro diretório e outro projeto Compose para
verificar a restauração sem reutilizar os volumes originais.

```bash
umask 077
restauracao=$(mktemp -d /srv/dms-restauracao.XXXXXX)
docker compose down &&
  tar --numeric-owner -cpf "$restauracao/backup.tar" dados &&
  cp compose.yml testar.py "$restauracao/" &&
  tar --numeric-owner -xpf "$restauracao/backup.tar" -C "$restauracao"
```

Só continue se a cadeia terminar com sucesso. O arquivo inclui as caixas,
o estado, a configuração e a chave TLS de teste. O original fica parado
enquanto a restauração usa o mesmo IP de teste.

```bash
cd "$restauracao"
docker compose -p dms-restauracao up -d
docker compose -p dms-restauracao logs --tail 50 mailserver
python3 testar.py conferir "$id_mensagem"
```

O mesmo ID deve aparecer confirmado na caixa de Bruno. Se algum comando
falhar, inspecione os logs da restauração e preserve os dados de origem para
repetir. Ao terminar, remova o projeto temporário e volte ao original se
quiser continuar explorando.

```bash
docker compose -p dms-restauracao down
cd /srv/docker-mailserver
docker compose up -d
```

## 4. Destruir a VM

Da pasta `terraform`, confira os recursos no state. A destruição apaga
também as caixas, os certificados, o backup local e os arquivos restaurados
na VM. Exporte antes qualquer evidência sanitizada que queira guardar.

```bash
terraform state list
terraform plan -destroy -out=mailserver-destruir.tfplan
terraform show mailserver-destruir.tfplan
terraform apply mailserver-destruir.tfplan
terraform state list
```

Confirme que o plano destrói somente os recursos deste experimento e que o
state termina vazio. Ao recriar a VM 903, a chave SSH vai mudar. Se o SSH
avisar dessa troca, confirme a identidade pelo console do Proxmox antes de
remover a chave antiga com `ssh-keygen -R 10.60.0.103`.
