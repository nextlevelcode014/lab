#!/usr/bin/env python3
"""Validação real no LXC 902. Requer contexto privado e workload do README."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import hashlib


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          env={**os.environ, 'LC_ALL': 'C'}).stdout.strip()


def exigir(condicao, mensagem):
    if not condicao:
        raise RuntimeError(mensagem)


def estado():
    paths = ('/etc/systemd/network/eth0.network',
             '/etc/systemd/network/eth0.network.d/50-lab-baseline.conf',
             '/etc/systemd/resolved.conf.d/50-lab-baseline.conf')
    ts = json.loads(run('tailscale', 'status', '--json'))
    exigir(ts['BackendState'] == 'Running', 'Tailscale não está Running')
    exigir('tag:lab' in ts['Self'].get('Tags', []), 'Nó precisa ter tag:lab')
    return {
        'hashes': {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths},
        'rota': run('ip', '-4', 'route', 'show', 'default'),
        'docker': json.loads(Path('/etc/docker/daemon.json').read_text()),
        'node_id': ts['Self']['ID'],
        'accept_dns': json.loads(run('tailscale', 'debug', 'prefs'))['CorpDNS'],
        'units': {u: {c: run('systemctl', c, u) for c in ('is-active', 'is-enabled')}
                  for u in ('tailscaled', 'systemd-resolved', 'docker')},
        'container_id': run('docker', 'inspect', '--format', '{{.Id}}', 'dns-pr69-workload'),
    }


def conferir_dns(contexto, privado_docker):
    run('resolvectl', 'flush-caches')
    exigir('-- link: eth0' in run('resolvectl', 'query', '-4', 'example.com'),
           'DNS público não usou eth0')
    exigir(bool(run('getent', 'ahostsv4', 'example.com')), 'DNS público sem resposta')
    for nome in (contexto['fqdn'], contexto['fqdn'].split('.', 1)[0]):
        exigir(contexto['ip'] in run('getent', 'ahostsv4', nome).split(),
               'MagicDNS do host retornou resposta inesperada')
    for nome in (['example.com', contexto['fqdn'], contexto['fqdn'].split('.', 1)[0]]
                 if privado_docker else ['example.com']):
        out = run('docker', 'run', '--rm', '--pull=never', '--network', 'bridge',
                  '--entrypoint', 'busybox', 'postgres:16-alpine', 'nslookup', nome)
        if nome != 'example.com':
            exigir(contexto['ip'] in out.split(), 'MagicDNS do Docker retornou resposta inesperada')
    exigir(run('docker', 'exec', 'dns-pr69-workload', 'psql', '-U', 'postgres', '-Atc',
               'SELECT valor FROM sentinela;') == 'pr69', 'Sentinela SQL não foi preservada')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fase', choices=('registrar', 'novo', 'rollback'))
    parser.add_argument('--contexto', default='/root/pr69-contexto.json')
    args = parser.parse_args()
    os.umask(0o077)
    exigir(os.geteuid() == 0, 'Execute como root dentro do LXC de teste')
    exigir(run('hostname') == 'lab-dns-pr69' and run('systemd-detect-virt') == 'lxc',
           'Alvo não é o LXC de teste')
    contexto = json.loads(Path(args.contexto).read_text())
    atual = estado()
    exigir(not atual['accept_dns'], 'accept-dns precisa permanecer false')
    exigir(all(u['is-active'] == 'active' for u in atual['units'].values()),
           'Todos os serviços precisam estar ativos')
    conferir_dns(contexto, privado_docker=args.fase == 'novo')
    baseline_path = Path('/root/pr69-baseline.json')
    if args.fase == 'registrar':
        with baseline_path.open('x') as f:
            json.dump(atual, f)
    else:
        antes = json.loads(baseline_path.read_text())
        for key in ('hashes', 'rota', 'node_id', 'accept_dns', 'units', 'container_id'):
            exigir(atual[key] == antes[key], 'Estado divergente do baseline: ' + key)
        if args.fase == 'novo':
            exigir({k: v for k, v in atual['docker'].items() if k != 'dns'} ==
                   {k: v for k, v in antes['docker'].items() if k != 'dns'},
                   'Opções Docker alheias ao DNS foram alteradas')
            exigir(atual['docker']['dns'] == ['172.17.0.1'], 'DNS do Docker não usa listener local')
            exigir('DNSOverTLS=yes' in Path('/etc/systemd/network/eth0.network.d/60-lxc-dns.conf').read_text(),
                   'DoT público obrigatório ausente')
        else:
            exigir(atual['docker'] == antes['docker'], 'Docker não voltou ao baseline')
            spec = importlib.util.spec_from_file_location('snapshot', '/root/lxc-dns-estado-pr69.py')
            snapshot = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(snapshot)
            salvo = json.loads(Path('/root/antes-pr69-tailnet/estado.json').read_text())
            exigir(snapshot.ler_arquivos(Path('/'), 'eth0') == salvo['arquivos'],
                   'Arquivos, links, permissões ou ausências não foram restaurados')
            exigir(run('systemctl', 'show', 'docker', '-p', 'InvocationID', '--value') !=
                   Path('/root/pr69-docker-antes-rollback').read_text().strip(),
                   'Rollback não reiniciou o Docker')
    print('APROVADO:', args.fase, '(DNS, serviços, Docker e sentinela SQL)')


if __name__ == '__main__':
    try:
        main()
    except (subprocess.CalledProcessError, RuntimeError, OSError, KeyError, ValueError) as exc:
        # Chamadas DNS podem conter o domínio privado; não imprimir argv/stdout.
        if isinstance(exc, subprocess.CalledProcessError):
            print('FALHOU: comando', ' '.join(exc.cmd[:2]), 'rc=', exc.returncode)
        else:
            print('FALHOU:', str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__)
        raise SystemExit(1)
