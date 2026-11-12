# AndBible com WebDAV

Primeira etapa do [piloto #86 do infra](https://forge.nextlevelcode.pro/nextlevelcode/infra/issues/86).
Cada pessoa usa uma conta e uma pasta próprias. O AndBible roda nos
aparelhos e sincroniza pela tailnet com o Apache no LXC 903. O LXC usa o
pool `lab`, a bridge isolada `vmbr2` e o nó efêmero `lab-andbible`.
O Tailscale Serve termina o HTTPS dos clientes. O Apache escuta só no
loopback, também com TLS para aceitar URLs HTTPS em operações DAV como
`MOVE`. Os dados ficam no disco do LXC em `/srv/andbible/dav`. Use dados
descartáveis de teste. O piloto está sem backup.

## Subir

1. Da raiz deste checkout, prepare o vault cifrado do lab com
   `ansible-vault edit vault.yml` e adicione `vault_andbible_dav_hashes`
   conforme [o exemplo](../../vault.yml.example). Rode `openssl passwd -6`
   no terminal duas vezes, cada vez com uma senha aleatória diferente
   guardada no gerenciador de senhas. Confira que ambos os hashes começam
   com `$6$` e estão associados à conta certa. As senhas são escolhidas
   fora do Ansible para serem entregues separadamente a cada pessoa.
   O vault também precisa da chave efêmera com `tag:lab`. Em checkout
   isolado, copie apenas o vault **cifrado** do lab. Confira a [configuração
   de SSH](../../docs/proxmox.md#5-ssh-da-sua-máquina-para-as-vms).
2. Confira que o VMID está livre e o template Ubuntu está presente. Essas
   leituras no host antecedem o primeiro provisionamento.

   ```bash
   ssh root@proxmox 'pvesh get /cluster/nextid --vmid 903 && pvesm list local --content vztmpl'
   ```

   Confira o retorno `903` e o template `ubuntu-26.04-standard_26.04-1_amd64.tar.zst`.
   A partir da raiz do lab, use o token de `lab@pve` e a chave pública do
   lab no arquivo local, conforme o exemplo.

   ```bash
   cd experimentos/andbible/terraform
   cp terraform.tfvars.example terraform.tfvars
   "${EDITOR:-vi}" terraform.tfvars
   terraform init
   terraform plan -out=andbible.tfplan
   terraform apply andbible.tfplan
   ```

   No primeiro plano, confira duas criações (LXC e host Ansible), o VMID
   903, o pool `lab`, a bridge `vmbr2` e a ausência de alterações em
   recursos existentes. O plano também deve mostrar `nesting = true`,
   exigido pelo systemd do template Ubuntu mesmo sem Docker. Guarde o
   plano localmente, pois pode conter segredos.
3. Libere o TUN e inicie apenas o LXC dedicado. O passthrough do dispositivo
   exige `root@pam` no Proxmox, fora das permissões do token do lab.

   ```bash
   ssh root@proxmox 'set -e
   config=$(pct config 903)
   printf "%s\n" "$config" | grep -qx "hostname: lab-andbible"
   printf "%s\n" "$config" | grep -qx "unprivileged: 1"
   printf "%s\n" "$config" | grep -E "^net0: .*bridge=vmbr2(,|$)"
   printf "%s\n" "$config" | grep -E "^features: (.*[, ])?nesting=1(,|$)"
   pct set 903 --dev0 /dev/net/tun
   pct start 903
   pct exec 903 -- test -c /dev/net/tun'
   ```

   A última checagem deve terminar com código zero. Se a primeira execução
   parar após o start, confira o TUN e o estado do LXC antes de repetir
   esses comandos.
4. Configure o LXC a partir do diretório Terraform.

   ```bash
   cd ../ansible
   ansible-playbook playbook.yml --limit lab-andbible
   ```

   Confira zero falhas e o nó efêmero com `tag:lab` no console do Tailscale.
   Caso o console solicite, habilite MagicDNS e certificados HTTPS conforme
   as [instruções do Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve).
   A partir de um desktop administrativo, confira o endereço, o certificado
   e as versões do servidor (o acesso SSH salta pelo Proxmox):

   ```bash
   ssh -J root@proxmox -i ~/.ssh/lab.pub -o IdentitiesOnly=yes root@10.60.0.103 \
     'tailscale ip -4; tailscale serve status; tailscale version; apache2 -v'
   ```

   O status deve mostrar a URL HTTPS privada do nó. O nome do nó pode
   ganhar um sufixo caso o MagicDNS já tenha outro com o mesmo nome.
5. A política da tailnet precisa permitir que os dois aparelhos alcancem
   somente a porta TCP 443 do LXC. Aplique a mudança revisada pelo
   [procedimento do infra](https://forge.nextlevelcode.pro/nextlevelcode/infra/src/branch/main/ansible/tailscale/README.md)
   após o merge do PR da política. Confira o IP do LXC pelo passo anterior e
   os IPs dos aparelhos pelo console **Machines**. A política é aplicada
   manualmente no console, que valida os testes antes de salvar.

## Conferir o endpoint

Use a URL HTTPS que o `tailscale serve status` mostrou. No desktop
administrativo, teste a conta e o isolamento antes de passar o acesso
aos participantes. O `curl` pede a senha no terminal ao usar `--user teste-1`.

```bash
base='https://lab-andbible.<tailnet>.ts.net'
dav="$base/dav/teste-1"
outro="$base/dav/teste-2"
amostra="checagem-$(date +%s)"

curl -sS -o /dev/null -w '%{http_code}\n' -X PROPFIND -H 'Depth: 0' "$dav"
curl -sS -o /dev/null -w '%{http_code}\n' --user teste-1 -X PROPFIND -H 'Depth: 0' "$dav"
curl -fsS --user teste-1 -X MKCOL "$dav/$amostra"
curl -fsS --user teste-1 -T - "$dav/$amostra/nota.txt" <<< 'anotação de teste'
curl -fsS --user teste-1 -X MOVE -H "Destination: $dav/$amostra/movida.txt" "$dav/$amostra/nota.txt"
curl -fsS --user teste-1 "$dav/$amostra/movida.txt"
curl -sS -o /dev/null -w '%{http_code}\n' --user teste-1 -X PROPFIND -H 'Depth: 0' "$outro"
curl -sS -o /dev/null -w '%{http_code}\n' --user teste-1 -X COPY -H "Destination: $outro/$amostra.txt" "$dav/$amostra/movida.txt"
curl -fsS --user teste-1 -X DELETE "$dav/$amostra"
```

Esperado: `401` sem credenciais, `207` com a conta certa, o texto de teste
após o `MOVE` e `401` ou `403` nas duas tentativas entre contas. Repita
invertendo as contas. Para conferir que ambos os aparelhos chegam ao
servidor pela tailnet, abra a URL individual em cada navegador e confirme
que aparece o pedido de autenticação via HTTPS.

## Começar no AndBible

1. Em cada aparelho com Tailscale conectado, abra uma instalação ou
   perfil limpo do AndBible. Anote a versão do app e do sistema.
2. No menu do AndBible, abra **Configurações de sincronização** e selecione
   **WebDAV**. Informe a URL HTTPS terminada em `/dav/teste-1` ou
   `/dav/teste-2`, o usuário correspondente e a senha. Deixe a subpasta
   opcional vazia. O participante insere a própria senha e habilita as
   categorias que quer testar no aparelho.
3. Adicione, edite e apague uma anotação fictícia. Teste marcações,
   etiquetas, planos, progresso e cadernos de estudo. Registre quais
   categorias sincronizam e o tempo até a outra instalação ver as mudanças.
   Para testar sincronização entre dois aparelhos, use a **mesma conta de
   teste** nos dois durante esse ensaio. As contas individuais permitem
   testar experiências independentes. Inclua uma edição offline e confira
   o resultado depois de reconectar.

Consulte o [guia de sincronização do AndBible](https://andbible.org/docs/cloud_sync/)
para os menus e o comportamento da primeira sincronização. Registre as
observações na issue #86 sem incluir URLs privadas nem credenciais.

## Encerrar

Desligue a sincronização e remova as credenciais do piloto nos aparelhos.
Remova o grant temporário pelo fluxo do `infra`, que aplica a política
no console após o merge. Confira que os dois aparelhos perderam acesso.
No diretório `experimentos/andbible/terraform` que contém o state do piloto,
revise o plano e, após autorizar o descarte, execute:

```bash
terraform plan -destroy -out=andbible-destroy.tfplan
terraform apply andbible-destroy.tfplan
terraform state list
```

O plano deve remover só o LXC 903 e seu host de inventário. Confira que o
state ficou vazio. No console Tailscale, verifique a remoção do nó efêmero e,
caso ainda apareça, remova apenas o nó do piloto.
