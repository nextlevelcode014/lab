# 03 — Inicialização do projeto: o que o `terraform init` faz

Desta vez o `terraform/` começa vazio (só o `terraform.tfvars.example`): você
escreve o projeto do zero e acompanha cada coisa que o `init` cria. O recurso
é o mesmo do tópico 1, uma VM vazia e desligada no VMID 990.

## Antes

Tailscale ligado e o token no tfvars, como no [tópico 1](../01-introducao/README.md):

```bash
cd experimentos/roadmap-terraform/03-inicializacao/terraform
cp terraform.tfvars.example terraform.tfvars
```

## Passos

1. **Escreva o projeto.** Sem copiar dos outros tópicos, crie `versions.tf`,
   `provider.tf`, `variables.tf` e `main.tf` para uma VM `roadmap-03`, VMID
   990, pool `lab`, desligada. No `versions.tf`, o provider
   `bpg/proxmox` com `version = "~> 0.114"`. Confira com
   `terraform fmt` e, depois do passo 3, `terraform validate`.
2. **Antes do init.** `terraform plan`: leia o erro.
3. **init.** `terraform init`. Depois olhe o que apareceu:

   ```bash
   find .terraform -maxdepth 6
   du -sh .terraform
   cat .terraform.lock.hcl
   terraform providers
   ```

   Qual versão foi escolhida, e de onde ela veio?
4. **Constraint que o lock não satisfaz.** Troque para `version = "= 0.117.0"`
   e rode `terraform init`: leia o erro. Rode `terraform init -upgrade` e veja
   o lock de novo.
5. **Constraint larga de volta.** Volte para `version = "~> 0.114"` e rode
   `terraform init`. Qual versão ficou? Por que não a mais nova?
6. **Outras plataformas.** Conte os hashes `h1:` no lock, rode
   `terraform providers lock -platform=linux_amd64 -platform=linux_arm64` e
   conte de novo.
7. **Fechar o ciclo.** `terraform init -upgrade` (volta para a versão mais
   nova dentro de `~> 0.114`), depois `terraform plan` e `terraform apply`.
   Confira a VM 990 no Proxmox.

### Opcional: cache de providers

Cada tópico baixa o provider de novo (veja o `du -sh` do passo 3). Um cache
compartilhado evita isso. É configuração da sua máquina, fora do repo:

```bash
mkdir -p ~/.terraform.d/plugin-cache
echo 'plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"' >> ~/.terraformrc
```

O cache só é usado quando o diretório **já tem** `.terraform.lock.hcl`: num
projeto sem lock, o Terraform baixa de novo do registry para conferir os
hashes que vai gravar. Confira num tópico que já tem lock:

```bash
cd ../../01-introducao/terraform
rm -rf .terraform && terraform init   # 1ª vez: baixa e guarda no cache
cd ../../02-hcl/terraform
rm -rf .terraform && terraform init   # Using bpg/proxmox ... from the shared cache directory
```

## Destruir

```bash
terraform destroy
```

Confira: `terraform state list` vazio e a VM 990 sumiu do Proxmox. O que vai
para o git: os `.tf` e o `.terraform.lock.hcl`; nunca `.terraform/`, state ou
tfvars (o `.gitignore` da raiz já cuida disso).
