#!/usr/bin/env python3
"""Confere fixtures contra metadados sanitizados dos três alvos, sem copiar segredos."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
profiles = {'caddy': 'timer', 'forgejo': 'oneshot', 'vaultwarden': 'oneshot'}
for host, profile in profiles.items():
    audit = json.loads((root / '.private/producao' / (host + '-metadados.json')).read_text())
    files = audit['files']
    assert audit['accept_dns'] is False, host + ': preferência DNS mudou'
    assert json.loads(audit['docker']['dns']) == ['172.17.0.1'], host + ': DNS Docker mudou'
    assert files['/etc/resolv.conf']['link'] == '/run/systemd/resolve/stub-resolv.conf'
    assert files['/etc/.pve-ignore.resolv.conf']['sha256'] == hashlib.sha256(b'').hexdigest()
    assert not files.get('/etc/systemd/network/eth0.network.d/60-lxc-dns.conf')
    assert audit['dns']['/etc/systemd/network/eth0.network'] == [], host + ': DNS na interface base exige novo perfil'
    mappings = {'resolved.conf': '/etc/systemd/resolved.conf.d/60-lxc-dns.conf',
                'timer.service' if profile == 'timer' else 'oneshot.service.in': '/etc/systemd/system/lxc-magicdns.service'}
    if profile == 'timer':
        mappings.update({'magicdns.timer': '/etc/systemd/system/lxc-magicdns.timer',
                         'magicdns.sh.in': '/usr/local/sbin/lxc-magicdns'})
    else:
        assert files['/usr/local/sbin/lxc-magicdns'] is None
        assert files['/etc/systemd/system/lxc-magicdns.timer'] is None
    for fixture, target in mappings.items():
        value = (root / 'legado' / fixture).read_text().replace('@TAILNET@', '<tailnet>.ts.net')
        digest = hashlib.sha256(value.encode()).hexdigest()
        assert digest in (files[target].get('sha256'), files[target].get('sha256_sanitizado')), host + ': fixture divergente ' + fixture
        assert files[target]['uid'] == 0 and files[target]['gid'] == 0
        assert files[target]['mode'] == (0o755 if target.endswith('/lxc-magicdns') else 0o644)
    wanted = {f'/etc/systemd/system/{t}.wants/lxc-magicdns.service': '/etc/systemd/system/lxc-magicdns.service'
              for t in ('multi-user.target', 'tailscaled.service', 'systemd-resolved.service')}
    if profile == 'timer':
        wanted['/etc/systemd/system/timers.target.wants/lxc-magicdns.timer'] = '/etc/systemd/system/lxc-magicdns.timer'
        assert audit['units']['lxc-magicdns.timer'] == {'is-active': 'active', 'is-enabled': 'enabled'}
    else:
        assert audit['units']['lxc-magicdns.service'] == {'is-active': 'active', 'is-enabled': 'enabled'}
    assert audit['links'] == wanted, host + ': vínculos mudaram'
    print('APROVADO: perfil auditado', host, '->', profile)
