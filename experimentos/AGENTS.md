# AGENTS.md

Leia também o [AGENTS.md da raiz](../AGENTS.md). Cada experimento documenta
pré-requisitos, execução, verificação e limpeza no seu `README.md`.
Exceções de um cenário não autorizam mudar os demais.

## Terraform

- Rode os comandos no `terraform/` do experimento ou exercício afetado;
  cada root module tem state próprio. Identifique o backend no código antes
  de inicializar; alguns exercícios estudam backends remotos do próprio lab.
- Preserve versões e locks. Segredos ficam no `terraform.tfvars`, fora do Git;
  mantenha o `.example` com os nomes das variáveis e valores públicos.
- Para código Terraform alterado, confira formatação e validação. Verificação
  offline usa cópia isolada sem backend, state ou credenciais reais; não mude
  a inicialização de um diretório operacional para fazer um check local.
- `plan`, `apply`, alterações de state e `destroy` reais seguem o escopo e a
  autorização da sessão. Confira alvos, custos e isolamento no README antes
  de executar. Documentar um comando não autoriza executá-lo.

## Ansible

- Rode dentro do `ansible/` do experimento, respeitando o `ansible.cfg` e o
  inventário locais. Quando houver `cloud.terraform`, ele lê o state do
  Terraform correspondente; não use inventário ou state de produção.
- Playbook com segredos carrega o vault próprio do lab conforme a raiz;
  check de sintaxe offline usa inventário isolado e não carrega esse vault.
- Cópias de roles da produção são independentes. Identifique origem por SHA
  completo e hashes dos arquivos; resultados históricos não aprovam uma
  cópia atualizada sem reexecutar os cenários afetados.
- Antes de execução remota, confirme os hosts e os efeitos esperados,
  inclusive em `--check --diff`. Não publique valores privados nos resultados.
