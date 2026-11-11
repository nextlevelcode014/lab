# servico

Módulo didático que registra uma configuração em `terraform_data`.
Não sobe aplicação, abre porta nem acessa serviços externos.

| Entrada | Tipo | Obrigatória | Padrão |
|---|---|---|---|
| `nome` | `string` não vazia | sim | — |
| `ambiente` | `string`, somente `lab` | sim | — |
| `porta` | `number`, inteiro entre 1 e 65535 | não | `8080` |

O output `resumo` publica `id` e `configuracao` (`nome`, `ambiente`, `porta`).
O exemplo de uso está no `main.tf` do root module, dois diretórios acima.
Terraform >= 1.4; apenas provider integrado e state do root que o chama.
