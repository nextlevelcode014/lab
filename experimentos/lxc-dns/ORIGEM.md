# Origem do role copiado

## Cópia atual

Fonte: `nextlevelcode/infra`, [PR #69](https://forge.nextlevelcode.pro/nextlevelcode/infra/pulls/69),
commit `11acf256c61aefecec401315096aca7f91d2c97e`, diretório
`ansible/roles/lxc_dns`.

Esta revisão inclui `tasks/limpar-legado.yml`. Depois de preparar o MagicDNS
global, o role usa `resolvectl revert tailscale0` quando ainda há DNS ou
domínio residual na interface. Esse estado pode persistir mesmo após
reiniciar o `systemd-resolved`.
[Registro da correção](https://forge.nextlevelcode.pro/nextlevelcode/infra/src/commit/11acf256c61aefecec401315096aca7f91d2c97e/ansible/docs/lxc-dns.md#regress%C3%A3o-do-estado-transit%C3%B3rio-em-04112026).

A cópia é independente. Ao atualizar, exporte o role do SHA de origem,
confira o conjunto de arquivos e atualize os hashes SHA-256 abaixo. Rode
os checks locais do [README](README.md#checks-offline) e registre no PR
quais cenários reais foram reexecutados.

```text
c651b41e4e3a37ba5643ecbf3df00036f605574cbde1085bfbde99b9ec4acf6e  defaults/main.yml
5a3ab78f34591d1b98f20c76f11bec85f3526adc607a270d92a06dcd5e733f64  files/estado.py
bba161b772f5aec0b95c50b882d7f8f007b4471a65c9162c9b1c64f450f9e4f7  handlers/main.yml
d91ec8e3c3be02c87b63283cf15ceb948823483156db7f1a290cf769ec12f66c  tasks/docker.yml
16c9501f1fc169f9efdba392244d455eff054bbf3372adc09e19bb16fa2b1b10  tasks/limpar-legado.yml
49dc69bdcd2502169ff9b5e6e1f112b6fe108048dff419bbd465e5649a208029  tasks/main.yml
bcdcd18e2eee1fdb84549150685a97ebbd3e87c0acaade2dc8d5e9cd751d5f7a  tasks/tailnet.yml
74409cb64fb49f78e503d7c320c7786128a36133a5841e32212d19bbbf6c7d90  templates/network-dns.conf.j2
f3f2ddd892ccb16440f415c3eda909ccd291aaf9fd6e917ebafd8ea0fcdacf69  templates/resolved.conf.j2
6ee1b8e3c4ab3afd570a09d7c18e7473598f6f78fb1484c4c1e426c4d5326e1d  tests/integracao.py
b4246d617f4c80e16d54d2febf34936a279a89794fd7d10ff943e9d39cc5a641  tests/provedores.py
3a60a8a9a86ca358e6f33f97365f8d139972fe494acb732d81858ceea0118b99  tests/test_estado.py
```

## Cópia histórica de 03/11/2026

Fonte: `nextlevelcode/infra`, PR #69, commit `5a4627f22978ce8322477784bc56dea62cec1983`.
Os hashes abaixo identificam a cópia usada nos ensaios históricos do
[README](README.md#resultados-hist%C3%B3ricos-de-03112026).

```text
c651b41e4e3a37ba5643ecbf3df00036f605574cbde1085bfbde99b9ec4acf6e  defaults/main.yml
5a3ab78f34591d1b98f20c76f11bec85f3526adc607a270d92a06dcd5e733f64  files/estado.py
bba161b772f5aec0b95c50b882d7f8f007b4471a65c9162c9b1c64f450f9e4f7  handlers/main.yml
d91ec8e3c3be02c87b63283cf15ceb948823483156db7f1a290cf769ec12f66c  tasks/docker.yml
4421c7f90c3cb89af0dd4ff7f765a3b6a1b4886056a7fb5e063482759d6d9d38  tasks/main.yml
bcdcd18e2eee1fdb84549150685a97ebbd3e87c0acaade2dc8d5e9cd751d5f7a  tasks/tailnet.yml
74409cb64fb49f78e503d7c320c7786128a36133a5841e32212d19bbbf6c7d90  templates/network-dns.conf.j2
f3f2ddd892ccb16440f415c3eda909ccd291aaf9fd6e917ebafd8ea0fcdacf69  templates/resolved.conf.j2
941c7e702fc75d99293652687c8abe8cd6f2d93b6d3c2e57d040b10d282c22a0  tests/integracao.py
b4246d617f4c80e16d54d2febf34936a279a89794fd7d10ff943e9d39cc5a641  tests/provedores.py
3a60a8a9a86ca358e6f33f97365f8d139972fe494acb732d81858ceea0118b99  tests/test_estado.py
```
