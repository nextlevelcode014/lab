# Tailscale: tag:lab

Máquina do lab entra na tailnet com `tag:lab`. A ACL (no repo `ansible`,
`tailscale/policy.hujson`) deixa os desktops de administração alcançarem o
lab, e **não** deixa o `tag:lab` alcançar nada da infra; os `tests` dela
falham o save se isso mudar.

A política tem que ter o `tag:lab` **antes** de gerar a chave: sem a tag em
`tagOwners`, o console não oferece a tag na chave.

## Auth key (uma vez, no navegador)

O console exige login; não há como gerar pela CLI sem outro token de API.

1. <https://login.tailscale.com/admin/settings/keys> → **Generate auth key**
2. **Reusable:** sim (vários experimentos) · **Ephemeral:** sim (a máquina
   some da tailnet quando morre) · **Tags:** `tag:lab` · validade: 90 dias
3. Guarde no Vaultwarden como "Tailscale auth key — lab".

## Vault do lab

A chave vai no `vault.yml` da raiz do lab (cifrado, fora do git; template em
`vault.yml.example`). Use uma senha **diferente** da do vault da produção:
vazar uma não abre a outra.

```bash
cd ~/Work/dev/lab
ansible-vault create vault.yml
```

No editor que abrir:

```yaml
vault_tailscale_authkey: "tskey-auth-..."
```

Confira: `head -1 vault.yml` mostra `$ANSIBLE_VAULT;1.1;AES256`, e
`ansible-vault view vault.yml` pede a senha e mostra a chave. Os playbooks
dos experimentos carregam esse arquivo e pedem a senha sozinhos
(`ask_vault_pass` no `ansible.cfg`).

Confira depois de um experimento subir: a máquina aparece em
<https://login.tailscale.com/admin/machines> com `tag:lab` e o selo
*Ephemeral*.
