# Coolify na Hetzner

O mesmo Coolify do [experimento da VM](../coolify/README.md), agora numa VPS
descartável da Hetzner (cx23, fsn1, Ubuntu 26.04), com IP público de verdade:
dá para testar deploy de um site com TLS como seria em produção, e a config
fica pronta para virar uma VPS paga só para o Coolify.

**Encerrado em 2026-10-12** (seção "Destruir"): nada deste experimento
está no ar. Para refazer, comece em "Antes, uma vez".

Como a VPS fica exposta:

| Porta | Pública | Pela tailnet |
|---|---|---|
| 80, 443 (sites, via proxy do Coolify) | sim | sim |
| 41641/udp (Tailscale direto), ICMP | sim | — |
| 22 (SSH / Ansible) | **não** | sim |
| 8000 (painel), 6001/6002 (realtime) | **não** | sim |

Quem fecha é o firewall da Hetzner (`terraform/firewall.tf`), fora da VPS: o
Docker publica as portas por cima do UFW, então um firewall dentro da VPS não
adiantaria. O servidor já nasce com ele (`firewall_ids`), sem janela aberta.

## Antes, uma vez

1. **Projeto e token na Hetzner** (no navegador: a API não cria projeto nem
   token). <https://console.hetzner.cloud> → **New project** `lab` → dentro
   dele, **Security → API tokens → Generate API token**, *Read & Write*.
   Guarde no Vaultwarden como "Hetzner API token — lab".
   Confira: o token aparece em *API tokens* do projeto **lab**, não no da
   produção. Um token só enxerga o projeto onde nasceu; é isso que impede o
   lab de ver a VPS de produção.
2. **Custo:** leia a seção Hetzner de [docs/nuvem.md](../../docs/nuvem.md).
3. **ACL do Tailscale** com `tag:lab`: [docs/tailscale.md](../../docs/tailscale.md)
   (já feito para o experimento da VM).
4. **tfvars:**

   ```bash
   cd experimentos/coolify-hetzner/terraform
   cp terraform.tfvars.example terraform.tfvars   # token do projeto lab + sua chave pública
   terraform init
   ```

## Subir

### 1. Auth key de uso único (no navegador, a cada `apply` que cria a VPS)

A chave vai no `user_data`, e o `user_data` fica legível para sempre no
metadata service da Hetzner (`169.254.169.254`), que qualquer container que o
Coolify rodar alcança. Por isso **não** é a chave reutilizável do
`vault.yml`: é uma só para esta VPS, que morre no primeiro uso. A console do
Tailscale exige login; não há como gerar sem outro token de API.

<https://login.tailscale.com/admin/settings/keys> → **Generate auth key**:
**Reusable:** não · **Ephemeral:** sim · **Pre-approved:** sim · **Tags:**
`tag:lab` · validade: 1 dia.

### 2. Terraform

```bash
cd experimentos/coolify-hetzner/terraform
read -rs TF_VAR_tailscale_authkey && export TF_VAR_tailscale_authkey   # cole a chave, Enter
terraform plan
terraform apply
unset TF_VAR_tailscale_authkey
```

O `read -rs` não ecoa e não deixa a chave no histórico do shell; ela não vai
para nenhum arquivo, e o state guarda só o hash do `user_data`. Sem a
variável, o `plan` para com "Criar a VPS exige a auth key"; com a VPS já
criada, `plan` e `destroy` não pedem a chave.

Confira: `terraform output ipv4` mostra o IP público, e em 1 a 3 minutos
`lab-coolify-hetzner` aparece em <https://login.tailscale.com/admin/machines>
com `tag:lab` e *Ephemeral*.

#### Se não aparecer na tailnet em 5 minutos

Sem a 22 pública, a tailnet é o único caminho por SSH. Quando o cloud-init
falha (auth key expirada ou já usada, instalador do Tailscale fora do ar), a
entrada é a console web da Hetzner. Ela é uma tela de VM no navegador e não
passa pelo firewall nem pela rede. Isso não dá para automatizar porque é
login na console.

1. <https://console.hetzner.cloud> → projeto **lab** → `lab-coolify-hetzner`
   → ícone **>_ Console**. A tela já mostra o fim do boot, com os erros do
   cloud-init, se houver.
2. Para logar, **Rescue → Reset root password**. A senha aparece uma vez só.
   Nem o `root` nem o `lab` têm senha (só chave), então sem isso a console
   não deixa entrar.
3. Logado como `root`:

   ```bash
   cloud-init status --long                  # "status: error" e o motivo
   grep -i -A5 tailscale /var/log/cloud-init-output.log
   tailscale status                          # "Logged out" = a auth key falhou
   ```

4. Corrija recriando, não à mão: a VPS ficou com senha de root, e o objetivo
   é que o código suba sozinho. Gere outra auth key (passo 1) e:

   ```bash
   read -rs TF_VAR_tailscale_authkey && export TF_VAR_tailscale_authkey
   terraform apply -replace=hcloud_server.coolify
   unset TF_VAR_tailscale_authkey
   ```

### 3. Ansible

```bash
cd ../ansible
ansible-playbook playbook.yml
```

Entra pela tailnet (`lab-coolify-hetzner.<tailnet>.ts.net`), espera o
cloud-init, roda o instalador oficial do Coolify e configura o backup com
borg (seção "Backup do host com borg"). Pede a senha do vault do lab: é de
lá que vem a passphrase do borg.

### 4. Painel (no navegador)

1. **Crie a conta de admin assim que o playbook terminar:** o primeiro
   cadastro vira admin. Abra `terraform output -raw painel`
   (`http://lab-coolify-hetzner.<tailnet>.ts.net:8000`).
2. **Settings → General → Domain: deixe vazio.** Preencher põe o painel
   atrás do proxy, nas portas 80/443 públicas. Ele fica só na 8000, só pela
   tailnet.
3. **Servers → localhost → General → Wildcard Domain:** confira que é o
   `terraform output -raw wildcard` (`http://<ip>.sslip.io`); se vier vazio,
   cole. É dele que o Coolify gera o domínio de cada site, sem mexer na
   Cloudflare.

### 5. Site de teste (no navegador)

1. **Sources → + Add → GitHub App** → nome `lab-coolify-hetzner` →
   **Webhook Endpoint: a URL da tailnet**
   (`http://lab-coolify-hetzner.<tailnet>.ts.net:8000`) → **Register Now** →
   o GitHub cria o app e devolve o navegador para essa URL → **Install** só
   no repositório do site, não em *All repositories*.

   Com o endpoint no IP público, a volta do GitHub dá
   `ERR_CONNECTION_TIMED_OUT`: a 8000 está fechada na internet. Na barra de
   endereço, troque só o host (`<ip>` → `lab-coolify-hetzner.<tailnet>.ts.net`),
   mantenha o caminho e o `?code=...`, e dê Enter logo: o `code` expira em
   minutos e vale uma vez. Se expirar, apague o app no GitHub (*Settings →
   Developer settings → GitHub Apps*) e a source no Coolify, e refaça.
2. **Projects → + Add → Resource → Private Repository (with GitHub App)** →
   o repo do site → build pack *Nixpacks* (detecta Next.js / estático
   sozinho) → **Deploy**.
3. No domínio que ele gerou, troque `http://` por `https://` para o Coolify
   pedir certificado do Let's Encrypt. O `sslip.io` é compartilhado por muita
   gente e às vezes bate no limite do Let's Encrypt; se o certificado não
   vier, teste em `http://` e anote.

O deploy automático a cada push **não** vai funcionar: o webhook do GitHub
aponta para o painel, que só existe na tailnet. Deploy pelo botão funciona
(o clone é de saída). Isso é um dos achados do teste, não um defeito a
contornar aqui.

## CI/CD: push → imagem no GHCR → deploy no Coolify

O deploy no push que o webhook não faz (o painel só existe na tailnet),
feito de outro jeito: o GitHub Actions faz o build, publica a imagem
**privada** no GHCR e entra na tailnet como nó efêmero com `tag:lab-ci` para
pedir o deploy à API do Coolify. Nada do Coolify fica público. A ACL deixa
`tag:lab-ci` chegar só na porta 8000 do `tag:lab` (repo `ansible`,
`tailscale/policy.hujson`).

O workflow testado está em [`exemplo-ci/deploy.yml`](exemplo-ci/deploy.yml)
(vai em `.github/workflows/` do repo do app), com o `Dockerfile` do app de
teste ao lado. O app em si (Bun + Postgres, frontend e API) foi o
`nextlevelcode014/coolify-teste-app`, descartável. A API de deploy do
Coolify é **POST** (`/api/v1/deploy?uuid=...`); GET responde 405.

**Deploy pelo sha, não pelo `:latest`.** O workflow troca a tag do app para
o sha do commit (`PATCH /api/v1/applications/<uuid>`) antes de pedir o
deploy. Com `:latest`, cada pull rouba o nome da versão anterior, que vira
`<none>` na VPS, e a aba **Rollback** do Coolify (que só lista imagens com
tag) fica vazia. O custo: trocar a tag exige token com `write`, que pode
mudar a configuração de qualquer app desse Coolify. A alternativa, ficar no
`:latest` com token só `deploy`, deixa o rollback para um `git revert`.

Na ordem (todos no navegador ou com segredo digitado por você; por isso, à
mão):

1. **ACL:** merge do PR da `tag:lab-ci` no repo `ansible` e colar a política
   no console (`tailscale/README.md` de lá). Confira: o save passa nos
   `tests`.
2. **OAuth client do Tailscale:** <https://login.tailscale.com/admin/settings/oauth>
   → **Generate OAuth client** → escopo **Auth Keys: Write** com a tag
   `tag:lab-ci`. O segredo aparece uma vez. É ele que gera, a cada job, uma
   auth key efêmera; o runner nunca vê uma chave reutilizável.
3. **Login do GHCR na VPS:** a imagem é privada, e quem faz o pull é o
   Docker da VPS. Crie um PAT **clássico** só com `read:packages`, validade
   curta (<https://github.com/settings/tokens/new>; o fine-grained não serve
   para o GHCR). Ponha no vault do lab e rode o playbook, que faz o
   `docker login` (play "Login do Docker no GHCR"):

   ```bash
   ansible-vault edit vault.yml   # na raiz do repo: vault_ghcr_pat: "ghp_..."
   cd experimentos/coolify-hetzner/ansible
   ansible-playbook playbook.yml
   ```

   Confira: `ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo docker pull
   ghcr.io/nextlevelcode014/coolify-teste-app:latest` baixa sem
   `unauthorized`. O token fica em `/root/.docker/config.json` (base64, não
   cifrado), fora de qualquer backup: é por isso que vem do vault, e cada
   VPS nova loga de novo pelo playbook.
4. **Banco:** no Coolify, **Projects → + Add → Resource → PostgreSQL** →
   **Start**. Copie a **Postgres URL (internal)**. Não ligue *Make it
   publicly available*: o banco fica só na rede Docker do Coolify.
5. **App:** **+ Add → Resource → Docker Image** →
   `ghcr.io/nextlevelcode014/coolify-teste-app:latest` → **Ports Exposes:**
   `3000` → em **Environment Variables**, `DATABASE_URL` = a URL interna do
   passo 4 → **Healthcheck:** path `/api/saude`, porta `3000` → domínio
   `https://` → **Deploy**. Confira: a página abre e o
   rodapé mostra `versão <sha do commit>`.
6. **API do Coolify:** **Settings → Advanced** → *API access* ligado e
   **Allowed API IPs** `100.64.0.0/10` (a faixa do Tailscale: a API só
   aceita quem vem da tailnet). Token em `/security/api-tokens` (o ícone na
   barra lateral é fácil de confundir com *Authentication*, que é login por
   OAuth, outra coisa) com **`write` e `deploy`**. O UUID do app é o pedaço
   da URL do painel depois de `/application/`.
7. **Segredos e variáveis no GitHub** (de dentro do repo do app; o
   `gh secret set` pede o valor sem ecoar):

   ```bash
   gh secret set TS_OAUTH_CLIENT_ID
   gh secret set TS_OAUTH_SECRET
   gh secret set COOLIFY_TOKEN
   gh variable set COOLIFY_HOST --body lab-coolify-hetzner
   gh variable set COOLIFY_APP_UUID --body <uuid>
   ```

   Sem a `COOLIFY_APP_UUID`, o workflow só publica a imagem e pula o deploy.
8. **Testar:** mude qualquer coisa no `public/index.html`, commit e push.
   Confira: `gh run watch` termina com os dois jobs verdes, e o rodapé da
   página passa a mostrar o sha novo.

Limpeza, além do `destroy`: apagar o repo e o pacote no GitHub
(*Packages* do perfil, se sobrar), revogar o PAT e o OAuth client.

## Backup no S3 da AWS

O bucket fica num state próprio ([`terraform-backup/`](terraform-backup/)),
separado da VPS: o teste é destruir a VPS e restaurar numa nova, e os
backups têm que sobreviver ao `destroy` dela.

Antes, uma vez: o usuário `lab-terraform` e o profile `lab`
([docs/nuvem.md](../../docs/nuvem.md), seção AWS).

```bash
cd experimentos/coolify-hetzner/terraform-backup
terraform init
terraform apply
terraform output                 # bucket, region, endpoint, access_key
terraform output -raw secret_key # só para colar no painel
```

O `apply` cria o bucket `lab-coolify-backup-<conta>` em `eu-central-1` e um
usuário `lab-coolify-backup` que só alcança esse bucket. É a chave dele que
vai no Coolify, nunca a do `lab-terraform`. Com versioning, um `DeleteObject`
(o Coolify apaga pela retenção) só esconde o arquivo por 7 dias, e essa chave
não tem `DeleteObjectVersion`: se vazar da VPS, não consegue apagar backup.

No painel: **S3 Storage** (barra lateral, acima de *Shared Variables*; ou
`/storages`) → **+ Add** → endpoint, bucket, region, access key e secret dos
outputs → **Validate Connection**. O Coolify testa com um `ListObjectsV2`.

### Backup da instância

**Settings → Backup** (`/settings/backup`) → **Configure backup** (cria o
agendamento diário `0 0 * * *`) → ligue o S3 com o storage acima →
**Backup Now**. O dump é do `coolify-db` (projetos, apps, variáveis, chaves),
e os segredos dentro dele estão cifrados com o `APP_KEY`, que **não** vai no
backup. Guarde-o à parte, com a versão do Coolify (o restore pede a mesma):

```bash
ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo grep '^APP_KEY=' /data/coolify/source/.env | wl-copy
```

Cole no Vaultwarden como "Coolify lab-coolify-hetzner — APP_KEY". O pipe
para o clipboard é para a chave não aparecer na tela nem no histórico.

Confira: a execução aparece como `success`, e o arquivo está em
`/data/coolify/backups/coolify/coolify-db-hostdockerinternal/` (o nome é o
host `host.docker.internal`, não o IP) e no bucket, com o mesmo caminho como
chave: `data/coolify/backups/...`.

### Backup e restore de um banco

Banco → **Backups** → **+ Add** → frequência, S3 ligado → **Backup Now**.
Para restaurar: banco → **Import Backup** → fonte **S3** → o caminho do
arquivo como aparece no bucket, com `/` na frente. Antes de confirmar, o
Coolify mostra o script que vai rodar. Ele:

- reconhece o formato pelo conteúdo (gzip, dump custom `PGDMP`, tar, SQL);
- roda `pg_restore --single-transaction --exit-on-error --no-owner --no-acl`:
  tudo ou nada, e os objetos ficam com o usuário do banco de destino;
- sem *Replace objects that already exist*, não tem `--clean`: se um objeto
  já existir, o restore falha e volta atrás inteiro.

Testado: `DROP TABLE` e restore pelo S3 trouxeram os dados e a sequência de
volta, e o app voltou a responder sem reiniciar. O que foi gravado depois do
último backup se perde: é a janela do dump.

**O `mc` do Coolify baixa pela versão** num bucket com versioning
(`s3:GetObjectVersion`), não pelo `GetObject` simples. Sem essa permissão, o
restore falha no download (sem tocar no banco), e um teste com
`aws s3api get-object` não pega isso.

### Retenção e falha

- **Retenção local e S3 são independentes** (aba *Retention*: *Local
  backups* e *S3 backups*, cada um com quantidade, dias e GB; `0` =
  ilimitado). No S3, o que a retenção apaga vira delete marker: a versão
  fica 7 dias (lifecycle) e a chave do Coolify não consegue apagá-la.
  Testado: S3 = 3 deixou os 3 mais novos na listagem e os antigos como
  versão recuperável.
- **S3 quebrado não vira falha.** Com a chave desativada na AWS, o backup
  do Postgres saiu com status `success`, `s3_uploaded = false` e a mensagem
  `Warning: S3 upload failed … InvalidAccessKeyId`. O dump local foi feito,
  mas o off-site parou sem nada vermelho na tela. Quem avisa é a
  notificação (`BackupSuccessWithS3Warning`), que vai pela mesma opção
  **Backup failure** dos canais de *Notifications*. Sem canal configurado,
  ninguém fica sabendo. (Volume com S3 quebrado: não testado.)
- **E-mail:** os campos do SMTP em *Settings → Email* não bastam. É preciso
  ligar o **Enabled** e, em *Notifications → Email* da equipe, **Use system
  wide (transactional) email settings**, com *Backup failure* marcado.
  O *From Address* tem que ser um endereço da conta do login SMTP (ou
  alias dela): com outro, o servidor recusa com `553 5.7.1 Sender address
  rejected: not owned by user`. Confira com **Send test email**.

### Backup de volume

Para aplicações e serviços (one-click, Compose), **não** para bancos
standalone: Redis, KeyDB e Dragonfly ficam sem backup nenhum pelo Coolify.
Recurso → **Storage Backups** (ou **Backups**) → **+ Add** → S3 ligado e
**Stop containers during archive** → **Backup Now**. Sai um `.tar.gz` do
volume em `/data/coolify/backups/volumes/...` e no bucket.

Testado com Uptime Kuma (SQLite em `/app/data`): com o container parado, o
`kuma.db` do tar passa no `PRAGMA integrity_check`. O tar copia o volume
como está: antes de terminar o assistente do Uptime Kuma, o volume só tinha
pastas vazias, e o backup saiu com 230 bytes e status `success`. Status
verde não diz que o backup tem dado; abra o arquivo.

O Coolify **não tem restore de volume** pelo painel: é extrair o tar à mão
no volume, com o container parado.

## Backup do host com borg (BorgBase)

O backup do Coolify não leva o `/data/coolify/source/.env` (o `APP_KEY`) nem
as chaves SSH, e só existe onde o Coolify o configura. O borg leva o
`/data/coolify` inteiro para a BorgBase, cifrado e deduplicado, junto com os
dumps e tars que o Coolify gera em `backups/`. Cada um faz o que sabe: o
Coolify gera a cópia consistente do banco, e o borg a leva para fora. Volume
cru de Postgres não entra: copiar o diretório de um banco rodando dá backup
inconsistente.

A play "Backup do host com borg" do `playbook.yml` instala o borg, gera a
chave SSH da VPS, cria o wrapper `borg-coolify` (repo, chave e passphrase já
configurados) e um timer diário às 01:30, depois dos backups do Coolify.

### Uma vez (no navegador e no vault)

O repo e a chave são criados na interface da BorgBase, que pede login.

1. <https://www.borgbase.com> → **Repositories → New repo** → nome
   `lab-coolify-hetzner`, região **EU**, *Alert*: **1 dia** sem backup →
   e-mail. Esse alerta é o que avisa se o backup parar sem erro visível.
   Copie a **Repository URL** (`ssh://...@....repo.borgbase.com/./repo`).
2. Gere a passphrase no Vaultwarden ("BorgBase — lab-coolify-hetzner") e
   ponha as duas no vault do lab:

   ```bash
   ansible-vault edit vault.yml   # na raiz do repo
   # vault_borg_repo: "ssh://..."
   # vault_borg_passphrase: "..."
   ```

### A cada VPS nova

1. `ansible-playbook playbook.yml` (pede a senha do vault). O fim mostra a
   chave pública do borg.
2. Na BorgBase: **Account → SSH keys → Add key** com essa chave → no repo,
   **Edit → Access** → a chave em **Append-only access**. Append-only grava
   backup novo, mas não apaga nem reescreve os antigos: uma VPS
   comprometida não destrói o histórico. A chave é por VPS e morre com ela;
   apague a velha na BorgBase depois de um `destroy`.
3. **Só na primeira VPS de todas:** criar o repo e exportar a chave dele.

   ```bash
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo borg-coolify init --encryption=repokey-blake2
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo borg-coolify key export :: - | wl-copy
   ```

   Cole a chave exportada no Vaultwarden, junto da passphrase. Com
   `repokey`, ela já fica dentro do repo, e a cópia é para o caso de o repo
   corromper.
4. Primeiro backup, sem esperar o timer:

   ```bash
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo systemctl start borg-coolify.service
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo borg-coolify list
   ```

   Confira: o `list` mostra um arquivo `lab-coolify-hetzner-<data>`, e o
   repo na BorgBase mostra o *Last backup*.

### Retenção

O `prune` **não** roda na VPS: com a chave append-only, apagar de lá não
libera espaço e pode ser desfeito, que é o ponto. A limpeza é de uma máquina
sua, com uma chave de acesso total no repo (*Full access*), de tempos em
tempos:

```bash
borg prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6 ssh://...repo
borg compact ssh://...repo
```

No lab, com poucos MB, não precisa.

## Recriar do zero e restaurar

Testado em 2026-10-11: `destroy` da VPS, VPS nova e tudo de volta, menos o
site do GitHub App (que já tinha sido apagado). Refeito em 2026-10-12
seguindo só este README, que foi corrigido onde faltava passo. A ordem importa. Os passos
"à mão" pedem navegador ou um segredo que você digita.

### Antes do destroy

1. **Backup Now** em cada banco e volume, e **por último** o da instância
   (`/settings/backup`): o `coolify-db` tem que conhecer tudo o que existe.
2. Borg na hora, para levar os dumps novos:

   ```bash
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo systemctl start borg-coolify.service
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo borg-coolify list --last 1
   ```

   Anote o nome do arquivo: é ele que os dois restores vão usar. Se
   perder, é o último do `borg-coolify list` com horário anterior ao
   `uptime -s` da VPS nova. Confira que ele
   tem os dumps do passo 1, com o horário de agora:

   ```bash
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo borg-coolify list ::<arquivo> \
     --format '"{mtime} {path}{NL}"' data/coolify/backups | grep -E '\.(dmp|tar\.gz)$'
   ```

   Precisa aparecer um `coolify-db-hostdockerinternal/pg-dump-coolify-*`
   e um arquivo de cada banco e volume. Numa VPS que acabou de ser
   restaurada, o `backups/` começa vazio (o restore não traz os dumps
   antigos para o disco): sem o passo 1, o arquivo sai sem nada para
   restaurar, e o borg não reclama.
3. Confira que o `APP_KEY` e a versão do Coolify estão no Vaultwarden. O
   borg também tem o `APP_KEY` (o `.env` inteiro), mas sem a passphrase do
   borg não há como chegar nele.

### Recriar

1. `terraform destroy` em `terraform/` (só a VPS: `terraform-backup/` fica)
   e `ssh-keygen -R lab-coolify-hetzner.<tailnet>.ts.net`.
2. **À mão:** apagar o nó em *Machines* do Tailscale e gerar outra auth key
   (seção "Subir", passo 1). `terraform apply`.
3. `ansible-playbook playbook.yml`: instala o Coolify na versão fixada
   (`coolify_version`), o login do GHCR e o borg. **Não crie a conta de
   admin**: o restore traz a antiga.
4. **À mão:** chave nova do borg na BorgBase, *append-only*; apague a velha.

### Restaurar a instância

```bash
cd experimentos/coolify-hetzner/ansible
ansible-playbook restore-instancia.yml -e borg_archive=<arquivo anotado>
```

Os playbooks de restore não usam o vault (o borg da VPS já tem a
passphrase). Para o `ansible.cfg` não pedir a senha à toa, prefixe com
`ANSIBLE_ASK_VAULT_PASS=false`.

Sem `-e borg_archive`, ele usa o último arquivo do borg, que só serve se a
VPS nova ainda não rodou backup (o timer é às 01:30). O playbook confere a
versão, recusa rodar numa instância que já tem usuário e então:

1. tira do borg o dump mais novo do `coolify-db` e o `.env` antigo;
2. troca **só** o `APP_KEY` no `.env` novo (as senhas de banco e Redis são
   da instalação nova);
3. para `coolify` e `coolify-redis`, roda o `pg_restore --clean` e o
   instalador de novo na mesma versão (migrations e containers);
4. troca no `authorized_keys` do root a chave da instalação nova (órfã:
   a privada dela sumiu com o banco substituído) pela pública da chave
   restaurada do servidor `localhost`, e testa o SSH do Coolify para o host.

Sem o `APP_KEY` antigo (testado): o painel sobe, o login funciona (a senha é
hash, não cifra), e toda tela que lê um segredo dá **500 "The MAC is
invalid"**: variáveis, chaves, S3, até o host do SMTP. Sem a troca no
`authorized_keys` (testado): *Servers → localhost* não valida, e nenhum
deploy acontece. Esse arquivo não está em backup nenhum, e não precisa: a
chave pública sai da privada restaurada.

Confira: login com a conta de antes, *Servers → localhost → Validate*
verde, e as telas de um app e do S3 abrem.

### Restaurar os apps

1. O login do GHCR já veio do `playbook.yml` (`vault_ghcr_pat`). É a única
   credencial dos apps que mora no host e não no `coolify-db`; sem ela o
   deploy dá `unauthorized` no pull.
2. Cada banco: **Start** (sobe vazio) → **Import Backup** → **S3** → o dump
   mais novo. Para achá-lo (o número no nome é o horário em epoch; confira
   com `date -u -d @<número>` que é de depois do passo 1 do "Antes do
   destroy"):

   ```bash
   aws --profile lab s3 ls --recursive s3://$(terraform -chdir=../terraform-backup output -raw bucket)/data/coolify/backups/databases/ \
     | sort | tail -3
   ```

   No painel, cole o caminho com `/` na frente. Se já importou um dump
   errado, importe o certo com **Replace objects that already exist**: as
   tabelas já existem, e sem ele o restore falha inteiro.
3. Cada app: **Deploy**.
4. Cada serviço com volume: **Deploy** (cria o volume vazio; não preencha
   assistente nenhum) e:

   ```bash
   ssh lab@lab-coolify-hetzner.<tailnet>.ts.net sudo docker volume ls   # <uuid do serviço>_<nome>
   ANSIBLE_ASK_VAULT_PASS=false ansible-playbook restore-volume.yml \
     -e volume=<nome do volume> -e borg_archive=<arquivo anotado>
   ```

   Ele tira do borg o tar mais novo daquele volume, para os containers que
   o usam, troca o conteúdo e sobe de novo. O nome do volume volta igual
   ao de antes (o UUID do serviço vem do `coolify-db`); no Uptime Kuma do
   teste, `9hf5hfr3fz9ma5r3pui1kutv_uptime-kuma-data`. Passe o mesmo
   arquivo do restore da instância: sem `-e borg_archive`, vale o último
   do borg, e depois do primeiro timer (01:30) esse é da VPS nova, sem o
   tar.

O que **não** volta com backup nenhum:

- **GitHub App apagado:** o deploy falha com `Integration not found`. A
  source é uma dependência externa; recrie o app ou troque por deploy key.
- **IP:** os domínios `*.sslip.io` (e o *Wildcard*) voltam com o banco,
  mas o `sslip.io` resolve para o IP escrito no nome. No teste a Hetzner
  devolveu o mesmo IP, por acaso. Com IP novo, troque os domínios no
  painel; com domínio próprio, atualize o registro A. Para não depender
  disso, um `hcloud_primary_ip` fora do servidor sobrevive ao destroy.
- Os certificados TLS: o Let's Encrypt emite de novo sozinho.

## Conferir

```bash
IP=$(terraform -chdir=../terraform output -raw ipv4)
curl -sI "http://$IP" | head -1            # responde (proxy do Coolify)
curl -m 5 "http://$IP:8000"                # timeout: painel fechado na internet
ssh -o ConnectTimeout=5 "lab@$IP"          # timeout: 22 fechada na internet
ssh lab@lab-coolify-hetzner.<tailnet>.ts.net true && echo ok   # pela tailnet
```

E o site abre no domínio `*.sslip.io` de fora da tailnet (celular no 4G).

## Destruir

Na ordem: a VPS, os backups e então as credenciais que vivem fora do
Terraform. Os passos à mão pedem login no navegador (GitHub, Tailscale,
BorgBase), e o lab não guarda token de API de nenhum deles: é de
propósito, e por isso não dá para scriptar.

### 1. A VPS

```bash
cd experimentos/coolify-hetzner/terraform
terraform destroy
ssh-keygen -R lab-coolify-hetzner.<tailnet>.ts.net
```

Apaga servidor, IP, firewall e chave SSH do projeto lab. Junto morre o
token da API do Coolify que o CI usa: ele mora no `coolify-db`.

Confira: `terraform state list` vazio, e o projeto **lab** vazio em
<https://console.hetzner.cloud>. O nó efêmero some sozinho da tailnet em
alguns minutos (`tailscale status | grep lab-coolify` sem saída). Se for
recriar logo em seguida, apague-o antes em *Machines*: com o nome ainda
ocupado, o novo entra como `lab-coolify-hetzner-1` e o Ansible bate no
velho.

### 2. Os backups no S3 (sem volta)

```bash
cd ../terraform-backup
terraform destroy
```

Apaga o bucket com tudo dentro, versões antigas incluídas
(`force_destroy`), e o usuário `lab-coolify-backup`. Fica em `destroy`
separado de propósito: é o único passo que perde dado.

Confira: `terraform state list` vazio (o Terraform só tira do state o que
a AWS confirmou ter apagado) e `aws --profile lab s3 ls | grep lab-coolify`
sem saída. O usuário IAM não dá para conferir com o profile `lab`: a
boundary não deixa o `lab-terraform` ler usuários (`GetUser` e `ListUsers`
dão *AccessDenied*), e isso é ela funcionando.

### 3. Credenciais, à mão

1. **GitHub App** (se ainda existir): GitHub → *Settings → Developer
   settings → GitHub Apps* → `lab-coolify-hetzner` → *Delete*. Ele continua
   com acesso ao repo depois que a VPS morre.
2. **Pacote no GHCR:** <https://github.com/nextlevelcode014?tab=packages> →
   `coolify-teste-app` → *Package settings* → *Delete this package*. O
   pacote não some junto com o repo.
3. **Repo do app** (`nextlevelcode014/coolify-teste-app`): apague em
   *Settings → Delete this repository*, ou, se ficar para testes futuros,
   apague em *Settings → Secrets and variables → Actions* os secrets do
   deploy (o token do Coolify e o OAuth client do Tailscale), que não
   servem mais para nada.
4. **PAT `read:packages`:** <https://github.com/settings/tokens> → *Delete*.
   Depois tire o `vault_ghcr_pat` do vault: `ansible-vault edit vault.yml`
   na raiz do repo.
5. **OAuth client do Tailscale:** <https://login.tailscale.com/admin/settings/oauth>
   → o da `tag:lab-ci` → *Revoke*. A tag fica na ACL: sem client, ela não
   dá acesso a nada, e um próximo experimento de CI a reaproveita.
6. **BorgBase:** <https://www.borgbase.com> → *Account → SSH keys* → apague
   as `borg@lab-coolify-hetzner` (uma por VPS que existiu). O repo:
   - **se ficar** (testes futuros): mantenha `vault_borg_*` no vault e a
     passphrase e a chave exportada no Vaultwarden. Sem elas, os arquivos
     viram lixo cifrado. A próxima VPS só precisa de chave nova, sem
     `init`;
   - **se for apagado:** *Repositories* → `lab-coolify-hetzner` → *Delete*,
     e então tire `vault_borg_*` do vault e a passphrase do Vaultwarden.
7. **Vaultwarden:** "Coolify lab-coolify-hetzner — APP_KEY" pode ir. Sem o
   bucket, não sobra backup da instância que precise dela (o `.env` dentro
   do borg tem a mesma chave).

Confira: nenhum token na lista do GitHub nem client na do Tailscale, e o
`coolify-teste-app` fora de <https://github.com/nextlevelcode014?tab=packages>.
Um `docker pull` não serve de prova: sem login, pacote privado e pacote
apagado dão o mesmo *denied*.

Ficam de propósito, porque são da conta e não do experimento: o projeto
**lab** e o token dele na Hetzner, o usuário `lab-terraform`, a policy
`lab-boundary` e o profile `lab` da AWS.

## Se virar uma VPS paga só para o Coolify

O código serve de base, mas a VPS de produção **não** nasce no lab (a
regra do repo): copie `terraform/` para o repo `terraform` (ao lado de
`hetzner/`) e o playbook para o repo `ansible`, e lá mude:

- token do projeto de produção, e `env = "lab"` → os labels de lá;
- Tailscale: chave **não** efêmera e uma tag própria (`tag:coolify`) com
  grants na ACL; `tag:lab` é descartável por definição;
- `delete_protection`, `rebuild_protection` e `prevent_destroy`, como na VPS
  de produção, e backups da Hetzner ou do `/data/coolify`;
- domínio de verdade na Cloudflare no lugar do `sslip.io`;
- deploy no push: a receita da seção CI/CD (runner na tailnet) dispensa o
  webhook do GitHub; numa VPS permanente, uma tag de CI própria em vez de
  `tag:lab-ci`.

## O que olhar no teste

- Deploy do site pelo GitHub App: tempo de build no cx23, uso de RAM, TLS
  no `sslip.io`.
- Se a falta de deploy no push pesa, e qual caminho para o webhook valeria.
- O que ele cria no host: redes Docker, `/data/coolify`, o proxy.
- Rolling update: no deploy, o container novo e o antigo atendem juntos por
  até um minuto (sem healthcheck, mais). Migration de banco tem que servir
  às duas versões.
