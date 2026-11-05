# Perfis legados de produção

Auditoria de leitura em 03/11/2026 nos três LXCs; somente hashes, metadados, campos DNS sanitizados e estados das units. Nenhuma configuração de produção foi alterada.

| Alvo | Perfil reproduzido | Origem do código |
|---|---|---|
| Caddy | timer ativo, script periódico e oneshot sem RemainAfterExit; quatro vínculos | infra `af3f64e` |
| Forgejo e Vaultwarden | oneshot active/exited com RemainAfterExit, sem timer nem script; três vínculos | infra `63d1070` |

Units/script conferidos contra hashes sanitizados (domínio substituído por `@TAILNET@`); resolved.conf idêntico por SHA-256 nos três hosts. O código foi copiado do histórico Git, não dos arquivos privados de produção.

Os perfis reproduzem DNS, units, script, modos, vínculos e habilitação. Nome, IP, credenciais e identidade são os do lab. O daemon Docker usa o mesmo DNS da produção (`172.17.0.1`), conservando o data-root e opções de logs do lab para manter a sentinela SQL; não se copiam dados ou opções privadas de produção.

```text
04c6c97e1411b8c4f19e066748eb80a4682b1195c925039a41f37f78bd325456  magicdns.sh.in
09d7de6616d5ca6fdc76638fdc1c5ae18c4760dd280a548502e3d06a5a62da3c  magicdns.timer
6d45cbe34a24989b2afd51e1c1259c807722df4bdab1903b080ad7621a555fd2  oneshot.service.in
9608385b6e75e0f320d2c968d310790fe9b74c38f73139659dd267e1b8a90051  resolved.conf
f9dd6b801d25fe7365b5abee131aa303226fbd94aa8cf1368782fc32c2588b26  timer.service
```
