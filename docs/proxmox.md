# Proxmox: pool, usuário e token do lab

O lab cria VMs com o usuário `lab@pve`, que só tem permissão no pool `lab`.
Um `terraform destroy` errado aqui não enxerga os containers da produção
(200–299), que ficam fora do pool.

Tudo abaixo roda **uma vez**, como `root` no Proxmox. Não dá para automatizar
pelo próprio lab: são justamente as permissões que o token do lab não pode
ter (criar usuário, mexer em storage, baixar imagem pela API exige
`Sys.Modify` na raiz).

```bash
ssh root@proxmox.<tailnet>.ts.net
```

## 1. Pool, usuário e token

```bash
pveum pool add lab --comment "Repo lab: tudo aqui é descartável"
pveum user add lab@pve --comment "Terraform do repo lab"
pveum user token add lab@pve terraform --privsep 0
```

O último comando mostra o segredo **uma vez só** (a coluna `value`, um
UUID). Guarde no Vaultwarden a string inteira, `lab@pve!terraform=<UUID>`:
ela é, sem mudar nada, o `proxmox_api_token` do `terraform.tfvars` de cada
experimento. Prefixo repetido (`lab@pve!terraform=lab@pve!terraform=…`) dá
`401 Authentication failed` só no `apply`: o `plan` de recurso novo nem
chama a API.

## 2. Permissões, só o necessário

```bash
# VMs: só os VMIDs do lab. Permissão de pool só vale para VM que já está no
# pool, e na criação o Proxmox confere /vms/<id> antes de pôr a VM lá
# (403 Permission check failed (/vms/900, VM.Config.Options)). ACL em VMID
# que ainda não existe é aceita, e assim a faixa 900-999 é imposta pelo
# próprio Proxmox, não só pela validação do módulo.
for id in $(seq 900 999); do
  pveum acl modify /vms/$id --users lab@pve --roles PVEVMAdmin
done
# Pool: pôr a VM criada no pool lab
pveum acl modify /pool/lab --users lab@pve --roles PVEVMAdmin,PVEPoolAdmin
# Discos: ler a imagem e o snippet do local, criar disco no local-lvm
pveum acl modify /storage/local --users lab@pve --roles PVEDatastoreUser
pveum acl modify /storage/local-lvm --users lab@pve --roles PVEDatastoreUser
# Rede: usar a bridge da LAN
pveum acl modify /sdn/zones/localnetwork/vmbr0 --users lab@pve --roles PVESDNUser
```

Se um `apply` falhar com `Permission check failed (<caminho>, <privilégio>)`,
acrescente só aquele privilégio naquele caminho. Nunca dê papel na raiz `/`:
é isso que separaria o lab da produção.

`403 (/vms/<id>, VM.Config.Options)` num VMID que já funcionou: um destroy
com purge apagou a ACL dele. Toda VM do lab leva `purge_on_destroy = false`;
para repor, `pveum acl modify /vms/<id> --users lab@pve --roles PVEVMAdmin`.

Confira: `pveum acl list | grep -c 'lab@pve'` mostra `104` (100 VMIDs +
pool + 2 storages + bridge).

Confira o isolamento (de qualquer máquina da tailnet), com o token novo:

```bash
curl -sk -H 'Authorization: PVEAPIToken=lab@pve!terraform=<segredo>' \
  'https://proxmox.<tailnet>.ts.net:8006/api2/json/cluster/resources?type=vm'
```

Tem que voltar `{"data":[]}`: o token não vê `caddy`, `forgejo`,
`vaultwarden` nem `pi-lab`.

## 3. Snippets no storage `local`

O cloud-init do lab usa um *vendor-data* que instala o qemu-guest-agent: é
por ele que o Terraform descobre o IP que o DHCP deu à VM.

```bash
pvesm set local --content iso,vztmpl,backup,import,snippets
mkdir -p /var/lib/vz/snippets
cat > /var/lib/vz/snippets/lab-vendor.yaml <<'YAML'
#cloud-config
packages:
  - qemu-guest-agent
runcmd:
  - systemctl enable --now qemu-guest-agent
YAML
```

Confira: `pvesm list local --content snippets` mostra
`local:snippets/lab-vendor.yaml`.

## 4. Imagem cloud do Ubuntu

```bash
cd /var/lib/vz/import
wget https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/releases/26.04/release/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
mv ubuntu-26.04-server-cloudimg-amd64.img ubuntu-26.04-server-cloudimg-amd64.qcow2
rm SHA256SUMS
```

O `sha256sum` tem que dizer `OK`. O `.img` da Ubuntu já é qcow2; o nome
`.qcow2` é o que o conteúdo `import` do Proxmox reconhece.

Confira: `pvesm list local --content import` mostra
`local:import/ubuntu-26.04-server-cloudimg-amd64.qcow2`.

Imagem nova (atualização da Ubuntu): repita o passo 4. VMs já criadas não
mudam; só as próximas.
