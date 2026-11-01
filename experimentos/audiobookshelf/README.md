# Audiobookshelf

Servidor self-hosted de audiolivros e podcasts, com app no celular que
sincroniza o progresso. Aqui é para avaliar antes de pensar em levá-lo ao
`infra`: o uso do dia a dia e, principalmente, se o backup volta.

Roda numa **VM** (901, `lab-audiobookshelf`), não em LXC: Docker em LXC
precisa de `keyctl`, `nesting` e `/dev/net/tun`, que só o `root@pam` liga
(no `infra` é o role `lxc_flags`, rodando como root no host). O lab não tem
esse acesso, de propósito.

## Antes, uma vez

- Proxmox preparado: [docs/proxmox.md](../../docs/proxmox.md)
- `tag:lab` na ACL, auth key e `vault.yml`: [docs/tailscale.md](../../docs/tailscale.md)
- Rede do lab no Proxmox (`vmbr2`): `ansible/docs/proxmox.md` do repo `infra`, "Rede do lab".
- SSH até as VMs do lab: [docs/proxmox.md](../../docs/proxmox.md), seção 5
  (o Ansible e o `scp` daqui saltam pelo Proxmox).
- Tailscale SSH do Proxmox autenticado: `ssh root@proxmox true`.

## Subir

```bash
cd experimentos/audiobookshelf/terraform
cp terraform.tfvars.example terraform.tfvars   # token do lab@pve + sua chave pública
terraform init
terraform plan
terraform apply
```

O `apply` espera o qemu-guest-agent responder (até 15 min no primeiro boot).
Confira: `terraform output ip` mostra `10.60.0.101` (o IP sai do VMID).

```bash
cd ../ansible
ansible-playbook playbook.yml   # pede a senha do vault do lab
```

**Defina a senha do root assim que o playbook terminar:** o primeiro acesso
ao painel cria o usuário `root`, e a porta 13378 está aberta para a tailnet
(o que a ACL deixa chegar ao `tag:lab`).

Confira:

- `lab-audiobookshelf` aparece na tailnet com `tag:lab` e *Ephemeral*;
- `http://lab-audiobookshelf:13378` abre a tela de criar o root.

O endereço é o nome curto, com o `http://` digitado: o `ts.net` está na
lista de HSTS dos navegadores, que trocam `http://` por `https://` em
qualquer `*.ts.net`, e o app só fala HTTP.

## Testar

1. **Biblioteca.** Baixe um ou dois livros de domínio público no
   <https://librivox.org> (o ZIP do MP3) e mande para a VM. Um diretório por
   livro, com o nome do livro:

   ```bash
   unzip livro.zip -d "Nome do Livro"
   scp -r "Nome do Livro" 10.60.0.101:/srv/audiobookshelf/audiobooks/
   ```

   No painel: *Settings → Libraries → Add Library*, tipo *Books*, pasta
   `/audiobooks`; depois *Scan*. Confira: o livro aparece com capa, autor e
   capítulos.

2. **Podcast.** Biblioteca nova, tipo *Podcasts*, pasta `/podcasts`; procure
   um podcast pelo nome e baixe um episódio. Confira: o episódio toca no
   navegador.

3. **Celular.** Instale o app Audiobookshelf, com o celular na tailnet, e
   aponte para `http://lab-audiobookshelf:13378`. Ouça uns
   minutos no celular e abra o mesmo livro no navegador. Confira: o
   navegador continua de onde o celular parou.

4. **Backup e volta.** É o que decide se ele vai para a produção. No
   painel: *Settings → Backups → Run Backup*. Traga o arquivo para fora da
   VM:

   ```bash
   scp "10.60.0.101:/srv/audiobookshelf/metadata/backups/*.audiobookshelf" .
   ```

   Destrua e recrie a VM (`terraform destroy`, `ssh-keygen -R 10.60.0.101`,
   `terraform apply`, o playbook de novo), suba os livros de novo pelo
   passo 1 e, no painel novo, *Settings → Backups → Upload*, e restaure. Confira: usuários,
   bibliotecas e o progresso do passo 3 voltaram. O backup leva o banco e
   as capas, não os áudios: o que isso quer dizer para o backup na
   produção?

## Destruir

```bash
cd experimentos/audiobookshelf/terraform
terraform destroy
ssh-keygen -R 10.60.0.101   # a VM recriada volta no mesmo IP, com host key nova
```

O `destroy` apaga a VM e os discos, com os livros de teste. O nó some da
tailnet sozinho (efêmero) em alguns minutos. Apague também o
`.audiobookshelf` que o passo 4 trouxe.

## O que olhar no teste

- Se a busca de metadados (capa, autor, série) acerta com livros reais.
- Como o app do celular lida com download para ouvir offline.
- O que ele grava e onde: `/srv/audiobookshelf/config` (SQLite) e
  `metadata/` (capas, cache, backups), para planejar volume e backup.
