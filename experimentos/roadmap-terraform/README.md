# roadmap-terraform

Exercícios do [roadmap.sh de Terraform](https://roadmap.sh/terraform), um
diretório por tópico, contra o Proxmox do lab (pool `lab`, VMIDs 990–999
reservados para estes exercícios, longe do 900 do coolify).

Cada tópico tem `terraform/` com state próprio e um `README.md` com os passos,
o que conferir e como destruir. Termine sempre com `terraform destroy`.

| Tópico | O que pratica |
|---|---|
| [01-introducao](01-introducao/README.md) | O ciclo da IaC: init, plan, apply, drift, destroy |
| [02-hcl](02-hcl/README.md) | Blocos, argumentos, referências, interpolação, funções, console |
| [03-inicializacao](03-inicializacao/README.md) | Projeto do zero: `init`, `.terraform/`, lock file, constraints, plataformas |
| [04-providers](04-providers/README.md) | Registry, endereço e nome local, configuração por ambiente, dois providers (Proxmox e AWS), alias, excluir versão |
| [05-recursos](05-recursos/README.md) | `count`, `for_each`, `depends_on`, `lifecycle` (`ignore_changes`, `replace_triggered_by`, `create_before_destroy`, `prevent_destroy`), `region` por recurso |
| [06-variaveis](06-variaveis/README.md) | Variável de entrada, tipos (`map(object)`, `optional`), `.tfvars`, `locals`, `TF_VAR_`, precedência, `validation` |
| [07-outputs](07-outputs/README.md) | `output`, `terraform output` (`-json`, `-raw`), `for` num mapa de `for_each`, `sensitive`, `nonsensitive`, `precondition`, `depends_on` |
