# 02 — HCL: blocos, argumentos e expressões

Duas VMs vazias e desligadas (VMIDs 990 e 991). A segunda, `vizinha`, não
repete valor nenhum: nome, VMID, tags, CPU e memória saem da `base` por
referência e expressão. O objetivo é ler e escrever HCL, não a VM.

## Antes

Tailscale ligado e o token no tfvars, como no [tópico 1](../01-introducao/README.md):

```bash
cd experimentos/roadmap-terraform/02-hcl/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
```

## Passos

1. **Anatomia.** Leia o `main.tf` e ache, no bloco `base`: o tipo do bloco,
   os dois rótulos, três argumentos e os blocos aninhados.
2. **Console.** `terraform console` avalia expressões sem criar nada. Teste,
   uma por linha (sai com `exit`):

   ```hcl
   "lab-${990 + 1}"
   ["a", "b", "c"][1]
   { cpu = 1, mem = 512 }["mem"]
   type({ cpu = 1, mem = 512 })
   join(", ", ["hcl", "lab"])
   990 >= 900 && 990 <= 999 ? "dentro" : "fora"
   upper("roadmap")
   ```

   Depois invente uma expressão sua com `length()` e uma com `format()`
   (documentação: <https://developer.hashicorp.com/terraform/language/functions>).
3. **plan.** `terraform plan`. Na `vizinha`, repare quais valores já aparecem
   calculados e qual fica `(known after apply)`. Por quê?
4. **apply.** `terraform apply`. Repare na ordem das linhas `Creating...`.
   Confira no Proxmox: 990 e 991, a 991 com o dobro da memória e as *Notes*
   citando a 990.
5. **Console de novo**, agora com o state preenchido:

   ```hcl
   proxmox_virtual_environment_vm.vizinha.description
   proxmox_virtual_environment_vm.base.tags
   ```

6. **Mude uma vez, mude as duas.** Troque `dedicated = 512` da `base` por
   `768` e rode `terraform plan`: quantos recursos mudam, e por quê?
   Aplique.
7. **Formatação.** Bagunce o alinhamento dos `=` e a indentação de um bloco,
   rode `terraform fmt -diff` e veja o que ele conserta.

## Destruir

```bash
terraform destroy
```

Repare na ordem das linhas `Destroying...`: é o inverso da criação.
Confira: `terraform state list` vazio, 990 e 991 sumiram do Proxmox.
