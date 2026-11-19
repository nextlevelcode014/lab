#!/usr/bin/env bash
# Executar no host Linux do laboratório, com Docker local e imagem já disponível.
set -euo pipefail
umask 077

arquivos=$(cd -- "$(dirname -- "$0")" && pwd)
temporario=$(mktemp -d /tmp/dms-catch-all.XXXXXX)
sufixo=${temporario##*.}
projeto="dms-catch-all-${sufixo,,}"
docker_local=(docker --host unix:///var/run/docker.sock)
compose=("${docker_local[@]}" compose -p "$projeto" -f "$temporario/compose.yml")
subida=0

limpar() {
    local resultado=$?
    trap - EXIT
    if ((subida)) && ! "${compose[@]}" down; then
        printf 'Confira o projeto %s e o diretório %s.\n' "$projeto" "$temporario" >&2
        exit 1
    fi
    rm -rf -- "$temporario"
    exit "$resultado"
}
trap limpar EXIT
trap 'exit 130' HUP INT TERM

export DMS_ENSAIO_IPV4=172.30.86.2
export DMS_ENSAIO_SUBREDE=172.30.86.0/24
cp -- "$arquivos/compose.yml" "$arquivos/testar.py" "$temporario/"
mkdir -p "$temporario/dados/config" "$temporario/dados/tls"
cp -- "$arquivos/postfix-virtual.catch-all.cf" "$temporario/dados/config/postfix-virtual.cf"

imagem=$("${compose[@]}" config --images)
if ! "${docker_local[@]}" image inspect "$imagem" >/dev/null; then
    printf 'Prepare a imagem fixada do experimento antes de executar o ensaio.\n' >&2
    exit 1
fi
"${compose[@]}" config --format json | python3 -c '
import json, sys
config = json.load(sys.stdin)
servico = config["services"]["mailserver"]
rede = config["networks"]["correio"]
assert set(config["services"]) == {"mailserver"}
assert not servico.get("ports") and not servico.get("network_mode")
assert set(servico["networks"]) == {"correio"}
assert rede.get("internal") and not rede.get("external")
'

senha=$(openssl rand -hex 24)
hash=$(printf '%s\n' "$senha" | openssl passwd -6 -stdin)
printf '%s|{SHA512-CRYPT}%s\n' ana@example.test "$hash" bruno@example.test "$hash" \
    > "$temporario/dados/config/postfix-accounts.cf"
openssl req -x509 -newkey rsa:2048 -noenc -days 1 -subj /CN=mail.example.test \
    -addext "subjectAltName=DNS:mail.example.test,IP:$DMS_ENSAIO_IPV4" \
    -keyout "$temporario/dados/tls/mail.key" -out "$temporario/dados/tls/mail.crt" 2>/dev/null

subida=1
if ! "${compose[@]}" up -d --wait --wait-timeout 120 --no-build --pull never; then
    "${compose[@]}" logs --tail 50 mailserver
    exit 1
fi
if ! DMS_SENHA_ENSAIO="$senha" python3 "$temporario/testar.py" catch-all; then
    "${compose[@]}" logs --tail 50 mailserver
    exit 1
fi
