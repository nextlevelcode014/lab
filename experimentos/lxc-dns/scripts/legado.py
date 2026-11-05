#!/usr/bin/env python3
"""Reproduz os perfis DNS legados auditados, exclusivamente no LXC 902."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path('/root/pr69-legado')
UNITS = ('lxc-magicdns.timer', 'lxc-magicdns.service')
BASE = Path('/root/pr69-legado-original')
PATHS50 = ('/etc/systemd/network/eth0.network.d/50-lab-baseline.conf',
           '/etc/systemd/resolved.conf.d/50-lab-baseline.conf')


def run(*args, check=True):
    return subprocess.run(args, text=True, capture_output=True, check=check,
                          env={**os.environ, 'LC_ALL': 'C'}).stdout.strip()


def require(value, msg):
    if not value:
        raise RuntimeError(msg)


def links():
    return {str(p): os.readlink(p) for p in Path('/etc/systemd/system').rglob('lxc-magicdns*') if p.is_symlink()}


def status():
    ts = json.loads(run('tailscale', 'status', '--json'))
    require(ts['BackendState'] == 'Running' and 'tag:lab' in ts['Self'].get('Tags', []), 'Tailscale do lab indisponível')
    return {'node_id': ts['Self']['ID'], 'accept_dns': json.loads(run('tailscale', 'debug', 'prefs'))['CorpDNS'],
            'docker': json.loads(Path('/etc/docker/daemon.json').read_text()),
            'container_id': run('docker', 'inspect', '-f', '{{.Id}}', 'dns-pr69-workload'),
            'network': Path('/etc/systemd/network/eth0.network').read_text(),
            'route': run('ip', '-4', 'route', 'show', 'default'), 'links': links(),
            'units': {u: {c: run('systemctl', c, u, check=False) for c in ('is-active', 'is-enabled')}
                      for u in (*UNITS, 'tailscaled', 'systemd-resolved', 'docker')}}


def dns(novo=False):
    ctx = json.loads(Path('/root/pr69-contexto.json').read_text())
    run('resolvectl', 'flush-caches')
    out = run('resolvectl', 'query', '-4', 'example.com')
    if novo:
        require('-- link: eth0' in out, 'DNS público fora de eth0')
    for name in (ctx['fqdn'], ctx['fqdn'].split('.', 1)[0]):
        require(ctx['ip'] in run('getent', 'ahostsv4', name).split(), 'MagicDNS do host divergente')
    for name in ('example.com', ctx['fqdn'], ctx['fqdn'].split('.', 1)[0]):
        out = run('docker', 'run', '--rm', '--pull=never', '--network', 'bridge', '--entrypoint',
                  'busybox', 'postgres:16-alpine', 'nslookup', name)
        if name != 'example.com':
            require(ctx['ip'] in out.split(), 'MagicDNS do Docker divergente')
    require(run('docker', 'exec', 'dns-pr69-workload', 'psql', '-U', 'postgres', '-Atc',
                'SELECT valor FROM sentinela;') == 'pr69', 'Sentinela SQL divergente')


def retirar_units():
    for unit in UNITS:
        p = Path('/etc/systemd/system') / unit
        if p.exists():
            run('systemctl', 'disable', '--now', unit)
            p.unlink()
    Path('/usr/local/sbin/lxc-magicdns').unlink(missing_ok=True)
    run('systemctl', 'daemon-reload')


def preparar(perfil):
    require(Path('/root/antes-pr69-tailnet/estado.json').is_file() and Path('/root/pr69-baseline.json').is_file(), 'Preparar e guardar primeiro o baseline original do lab')
    require(not (Path('/root') / ('antes-legado-' + perfil)).exists(), 'Snapshot já existe; não sobrescrever')
    BASE.mkdir(mode=0o700, exist_ok=True)
    for name in PATHS50:
        p = Path(name); backup = BASE / ('network50' if '/network/' in name else 'resolved50')
        if p.exists():
            require(not backup.exists(), 'Backup dos drop-ins já existe')
            p.rename(backup)
    retirar_units()
    marker = Path('/etc/.pve-ignore.resolv.conf'); marker.write_text(''); marker.chmod(0o644)
    require(Path('/etc/resolv.conf').readlink() == Path('/run/systemd/resolve/stub-resolv.conf'), 'Stub inicial divergente')
    Path('/etc/systemd/network/eth0.network.d/60-lxc-dns.conf').unlink(missing_ok=True)
    domain = json.loads(run('tailscale', 'status', '--json'))['Self']['DNSName'].rstrip('.').split('.', 1)[1]
    for source, target in [('resolved.conf', '/etc/systemd/resolved.conf.d/60-lxc-dns.conf'),
                           ('timer.service' if perfil == 'timer' else 'oneshot.service.in', '/etc/systemd/system/lxc-magicdns.service')]:
        p = Path(target); p.write_text((ROOT / source).read_text().replace('@TAILNET@', domain)); p.chmod(0o644)
    if perfil == 'timer':
        shutil.copyfile(ROOT / 'magicdns.timer', '/etc/systemd/system/lxc-magicdns.timer')
        Path('/etc/systemd/system/lxc-magicdns.timer').chmod(0o644)
        p = Path('/usr/local/sbin/lxc-magicdns')
        p.write_text((ROOT / 'magicdns.sh.in').read_text().replace('@TAILNET@', domain)); p.chmod(0o755)
    p = Path('/etc/docker/daemon.json'); d = json.loads(p.read_text()); d['dns'] = ['172.17.0.1']
    p.write_text(json.dumps(d, indent=2)); p.chmod(0o644)
    run('networkctl', 'reload'); run('networkctl', 'reconfigure', 'eth0')
    run('systemctl', 'restart', 'systemd-resolved')
    run('systemctl', 'daemon-reload')
    run('systemctl', 'enable', '--now', 'lxc-magicdns.service')
    if perfil == 'timer':
        run('systemctl', 'enable', '--now', 'lxc-magicdns.timer')
    run('systemctl', 'restart', 'docker')
    time.sleep(15)
    dns()
    snapshot = '/root/antes-legado-' + perfil
    run('python3', '/root/lxc-dns-estado-pr69.py', 'salvar', snapshot)
    Path(snapshot, 'evidencias.json').write_text(json.dumps(status()))
    print('APROVADO: baseline legado', perfil, 'e snapshot')


def conferir(perfil, novo):
    atual = status(); antes = json.loads(Path('/root/antes-legado-' + perfil, 'evidencias.json').read_text())
    for key in ('node_id', 'accept_dns', 'docker', 'container_id', 'network', 'route'):
        require(atual[key] == antes[key], 'Divergência em ' + key)
    for unit in ('tailscaled', 'systemd-resolved', 'docker'):
        require(atual['units'][unit] == antes['units'][unit], 'Estado divergente em ' + unit)
    if novo:
        require(not atual['links'], 'Vínculos legados ainda presentes')
        require(all(atual['units'][u]['is-active'] not in ('active', 'activating') for u in UNITS), 'Unit legada ainda ativa')
        runtime = run('resolvectl', 'status', 'eth0')
        require('+DNSOverTLS' in runtime and '86.54.11.100' in runtime and '1.1.1.1' in runtime and 'DNS Domain: ~.' in runtime, 'DNS público runtime divergente')
        for p in ('/usr/local/sbin/lxc-magicdns', '/etc/systemd/system/lxc-magicdns.service', '/etc/systemd/system/lxc-magicdns.timer'):
            require(not Path(p).exists(), 'Artefato legado não foi removido')
        require(Path('/etc/resolv.conf').readlink() == Path('/run/systemd/resolve/stub-resolv.conf'), 'Stub divergente')
        require(Path('/etc/.pve-ignore.resolv.conf').exists(), 'Marker ausente')
    else:
        spec = importlib.util.spec_from_file_location('estado', '/root/lxc-dns-estado-pr69.py')
        mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        snap = json.loads(Path('/root/antes-legado-' + perfil, 'estado.json').read_text())
        require(mod.ler_arquivos(Path('/'), 'eth0') == snap['arquivos'], 'Arquivos/metadados não restaurados exatamente')
        require(atual['links'] == antes['links'], 'Vínculos não restaurados exatamente')
        invocation = Path('/root/pr69-docker-rollback-' + perfil).read_text().strip()
        require(run('systemctl', 'show', 'docker', '-p', 'InvocationID', '--value') == invocation, 'Docker reiniciou sem mudança de configuração')
        for unit in UNITS:
            require(atual['units'][unit]['is-enabled'] == antes['units'][unit]['is-enabled'], 'Habilitação legada divergente')
        if perfil == 'timer':
            require(atual['units'][UNITS[0]]['is-active'] == 'active', 'Timer não voltou ativo')
            inicio = run('systemctl', 'show', UNITS[1], '-p', 'ExecMainStartTimestampMonotonic', '--value')
            time.sleep(7)
            require(run('systemctl', 'show', UNITS[1], '-p', 'ExecMainStartTimestampMonotonic', '--value') != inicio, 'Timer não voltou a executar o script')
        else:
            require(atual['units'][UNITS[1]]['is-active'] == 'active', 'Oneshot não voltou active/exited')
        require(run('systemctl', 'show', UNITS[1], '-p', 'ExecMainStatus', '--value') == '0', 'Unit legada falhou')
    dns(novo)
    print('APROVADO:', perfil, 'novo' if novo else 'rollback', '(DNS host/Docker, units, vínculos e SQL)')


def limpar():
    require(Path('/root/antes-pr69-tailnet/estado.json').is_file(), 'Snapshot original ausente')
    require(all((BASE / n).is_file() for n in ('network50', 'resolved50')), 'Backups dos drop-ins originais ausentes')
    retirar_units()
    for name in PATHS50:
        p = BASE / ('network50' if '/network/' in name else 'resolved50')
        require(p.exists(), 'Backup original ausente')
        shutil.copy2(p, name)
    run('python3', '/root/lxc-dns-estado-pr69.py', 'restaurar', '/root/antes-pr69-tailnet')
    run('python3', '/root/pr69-validar.py', 'rollback')
    print('APROVADO: laboratório restaurado ao baseline original')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('acao', choices=('preparar', 'novo', 'rollback', 'limpar'))
    p.add_argument('perfil', choices=('timer', 'oneshot'), nargs='?')
    a = p.parse_args(); os.umask(0o077)
    require(os.geteuid() == 0 and run('hostname') == 'lab-dns-pr69' and run('systemd-detect-virt') == 'lxc', 'Alvo diferente do LXC de teste')
    if a.acao == 'limpar': limpar()
    else:
        require(a.perfil is not None, 'Perfil obrigatório')
        if a.acao == 'preparar': preparar(a.perfil)
        else: conferir(a.perfil, a.acao == 'novo')


if __name__ == '__main__':
    try: main()
    except (subprocess.SubprocessError, OSError, ValueError, RuntimeError, KeyError) as e:
        print('FALHOU:', str(e) if isinstance(e, RuntimeError) else type(e).__name__)
        raise SystemExit(1)
