# AGENTS.md

Leia também o [AGENTS.md da raiz](../AGENTS.md). Estes módulos Terraform
são compartilhados apenas entre os experimentos deste lab.

- Preserve as validações de isolamento: no Proxmox, VMIDs 900–999, pool
  `lab` e bridge `vmbr2`. Não aceite credenciais ou módulos de produção.
- Antes de mudar uma interface ou comportamento, localize os experimentos
  que usam o módulo e descreva o impacto nesses consumidores no PR.
- Confira formatação do módulo e validação dos roots consumidores afetados,
  em cópias isoladas sem backend, state ou credenciais reais. Registre os
  consumidores não verificados e o motivo; uma validação estática não prova
  o comportamento no Proxmox.
- Mudança no módulo não autoriza criar, alterar ou destruir os recursos dos
  experimentos; a execução real mantém o escopo e a autorização próprios.
