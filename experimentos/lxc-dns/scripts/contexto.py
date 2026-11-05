#!/usr/bin/env python3
"""Guarda o peer do desktop em arquivo privado, sem publicar domínio/IP."""
import json
from pathlib import Path
import os
import subprocess

os.umask(0o077)
peer = json.loads(subprocess.check_output(['tailscale', 'status', '--json']))['Self']
assert peer['DNSName'] and peer['TailscaleIPs'], 'Desktop precisa estar na tailnet'
path = Path(__file__).resolve().parents[1] / '.private/contexto.json'
path.parent.mkdir(mode=0o700, exist_ok=True)
path.write_text(json.dumps({'fqdn': peer['DNSName'].rstrip('.'), 'ip': peer['TailscaleIPs'][0]}))
path.chmod(0o600)
print('Contexto privado salvo em .private/contexto.json')
