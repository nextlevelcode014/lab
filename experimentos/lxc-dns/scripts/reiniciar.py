#!/usr/bin/env python3
"""Registra a janela de recuperação após restart; não mascara falhas imediatas."""
import argparse
import json
import subprocess
import time
from pathlib import Path
import sys


def run(*args, timeout=10):
    return subprocess.run(args, check=True, text=True, capture_output=True,
                          timeout=timeout).stdout


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('servico', choices=('tailscaled', 'systemd-resolved'))
    args = p.parse_args()
    if run('hostname').strip() != 'lab-dns-pr69' or not Path('/root/pr69-baseline.json').is_file():
        raise RuntimeError('Execute somente no LXC de teste com baseline guardado')
    contexto = json.loads(Path('/root/pr69-contexto.json').read_text())
    run('systemctl', 'restart', args.servico, timeout=30)
    inicio = time.monotonic()
    checks = (
        ('tailscale_running', lambda: json.loads(run('tailscale', 'status', '--json'))['BackendState'] == 'Running'),
        ('publico_eth0', lambda: '-- link: eth0' in run('resolvectl', 'query', '-4', 'example.com')),
        ('magicdns_fqdn', lambda: contexto['ip'] in run('getent', 'ahostsv4', contexto['fqdn']).split()),
        ('magicdns_curto', lambda: contexto['ip'] in run('getent', 'ahostsv4', contexto['fqdn'].split('.', 1)[0]).split()),
    )
    for nome, check in checks:
        try:
            ok = check()
        except (subprocess.SubprocessError, OSError, KeyError, ValueError):
            ok = False
        print(json.dumps({'fase': 'imediata', 'teste': nome, 'ok': ok,
                          'segundos_apos_restart': round(time.monotonic()-inicio, 3)}), flush=True)
    time.sleep(max(0, 15 - (time.monotonic()-inicio)))
    # O validador completo inclui Docker real, hashes, identidade e sentinela SQL.
    result = subprocess.run([sys.executable, '/root/pr69-validar.py', 'novo'],
                            text=True, capture_output=True, timeout=90)
    print(json.dumps({'fase': 'apos_15s', 'matriz_completa': result.returncode == 0,
                      'segundos_apos_restart': round(time.monotonic()-inicio, 3)}), flush=True)
    return result.returncode


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (subprocess.SubprocessError, OSError, RuntimeError, KeyError, ValueError) as exc:
        print('FALHOU:', type(exc).__name__)
        raise SystemExit(1)
