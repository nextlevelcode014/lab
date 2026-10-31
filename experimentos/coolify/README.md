# Coolify

PaaS self-hosted (alternativa ao Heroku/Vercel): aponta um repositório Git e
ele faz build, container, proxy e TLS. Fica **fora** da stack de produção:
o estado dele mora no Postgres próprio e ele quer ser dono das portas 80/443,
o que briga com o Caddy e com o fluxo Git + Ansible. Aqui é só para conhecer.

Roda numa **VM** (900, `lab-coolify`), não em LXC: Docker em LXC precisa de
`keyctl`, que só o `root@pam` liga, e o token do lab não tem isso.

## Antes, uma vez

- Proxmox preparado: [docs/proxmox.md](../../docs/proxmox.md)
- `tag:lab` na ACL, auth key e `vault.yml`: [docs/tailscale.md](../../docs/tailscale.md)
- Rede do lab no Proxmox (`vmbr2`): `ansible/docs/proxmox.md` do repo `infra`, "Rede do lab".
- Tailscale SSH do Proxmox autenticado: `ssh root@proxmox true` (o Ansible salta por ele).

## Subir

```bash
cd experimentos/coolify/terraform
cp terraform.tfvars.example terraform.tfvars   # token do lab@pve + sua chave pública
terraform init
terraform plan
terraform apply
```

O `apply` espera o qemu-guest-agent responder (até 15 min no primeiro boot).
Confira: `terraform output ip` mostra `10.60.0.100` (o IP sai do VMID).

```bash
cd ../ansible
ansible-playbook playbook.yml   # pede a senha do vault do lab
```

**Crie a conta de admin assim que o playbook terminar:** o primeiro cadastro
no painel vira admin, e a porta 8000 está aberta para a tailnet (o que a ACL
deixa chegar ao `tag:lab`).

Confira:

- `lab-coolify` aparece na tailnet com `tag:lab` e *Ephemeral*;
- `http://lab-coolify.<tailnet>.ts.net:8000` abre o cadastro do Coolify.

## Destruir

```bash
cd experimentos/coolify/terraform
terraform destroy
ssh-keygen -R 10.60.0.100   # a VM recriada volta no mesmo IP, com host key nova
```

O `destroy` apaga a VM e os discos. O nó some da tailnet sozinho (efêmero)
em alguns minutos.

## O que olhar no teste

- Deploy de um repo Git (o site estático é um bom primeiro caso) e como ele
  lida com o TLS.
- Se a interface e o deploy com um clique fazem falta perto do fluxo
  Git + Ansible da produção.
- O que ele cria no host: redes Docker, `/data/coolify`, o proxy.
