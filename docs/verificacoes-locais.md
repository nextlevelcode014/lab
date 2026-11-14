# Verificações locais

Na raiz do repositório, com a revisão proposta em checkout:

```bash
python3 verificar.py pr origin/main HEAD
python3 verificar.py completo origin/main HEAD
```

Use como base a referência atual do destino do PR. O perfil `pr` seleciona
os checks pelo diff do ancestral comum com a base até o head. O perfil
`completo` roda todos os checks locais. O comando imprime os SHAs e testa
uma cópia temporária dos arquivos versionados no head. Faça um commit para
incluir alterações locais no ensaio. Um caminho fora das regras de seleção
exige classificação, e qualquer falha de ferramenta interrompe o comando.

| Alteração | Check | Efeito e dependências |
|---|---|---|
| Código de experimento | Formatação Terraform no root e nos módulos internos, `terraform init -backend=false -input=false -lockfile=readonly` e `terraform validate` em cada root do experimento | Providers fixados pelo lock. Inicialização pode baixar providers para a cópia temporária |
| Código em `modules/proxmox-vm` | Formatação do módulo e checks de `audiobookshelf` e `coolify` | Acrescente novos consumidores em `verificar.py` |
| Experimento com Ansible | Sintaxe dos playbooks com `ansible-playbook -i localhost, --syntax-check` | Inventário fictício e configuração isolada |
| Código no `lxc-dns` | Também roda `test_estado.py` e verifica a sintaxe Python dos scripts do experimento | O teste usa `systemctl --root` numa árvore temporária |
| `bootstrap/aws.sh` | `bash -n` | Checa a sintaxe sem executar o script |
| `verificar.py` | Todos os checks locais | Mesmo efeito dos checks individuais |
| Markdown, `.gitignore`, template do vault e exemplo de CI do Coolify | Conferência de valores privados no diff | Revisão do exemplo de CI é manual |

O exercício `10-formatar-e-validar` contém erros intencionais em
`main.tf.example`, que o participante corrige durante o exercício. Outros
exercícios são selecionados pelo diretório numerado. Os roots `terraform`,
`terraform-backup`, `bootstrap` e `consumidor` são validados isoladamente.

A conferência de privacidade roda nos dois perfis. Ela busca nomes de
tailnet e IPv4 Tailscale nas linhas acrescentadas, com exceções para os
endereços genéricos e para o domínio fictício do teste DNS. Mostra apenas os
caminhos suspeitos. Revise também os demais dados sensíveis antes de publicar.

## Dependências

Referência para reprodução em Linux: Git, Bash, Python **3.14.8**,
Terraform **1.15.9**, Ansible **14.5.0** (core **2.21.5**),
`artis3n.tailscale` **1.2.1** e systemd (`systemctl`). O pacote Ansible
inclui as demais coleções citadas pelos playbooks. A coleção adicional é
procurada em `~/.ansible/collections`, com alternativa explícita em
`--colecoes /caminho/collections`. O diretório deve conter
`ansible_collections/artis3n/tailscale`. Confira as versões antes do ensaio
e registre diferenças no PR.

Para usar apenas providers disponíveis num espelho local:

```bash
python3 verificar.py completo origin/main HEAD --espelho-providers /caminho/espelho
```

O espelho deve ter a estrutura de um
[filesystem mirror do Terraform](https://developer.hashicorp.com/terraform/cli/config/config-file#filesystem_mirror).
Se faltar uma versão do lock, a inicialização falha. O ambiente temporário
descarta configuração e variáveis da sessão, incluindo credenciais,
inventário operacional e configurações de proxy.

Para integração DNS por namespaces e ensaios com ambientes, siga o
[procedimento do experimento](../experimentos/lxc-dns/README.md).
