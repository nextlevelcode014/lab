import hashlib,json,os,re,stat,subprocess
from pathlib import Path

def run(*args):return subprocess.run(args,capture_output=True,text=True).stdout.strip()
def san(s):
 s=re.sub(r'[A-Za-z0-9-]+\.ts\.net','<tailnet>.ts.net',s)
 return re.sub(r'\b100\.(?:6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.\d+\.\d+\b',lambda m:m[0] if m[0]=='100.100.100.100' else '<ts_ip>',s)
paths=['/etc/resolv.conf','/etc/.pve-ignore.resolv.conf','/etc/docker/daemon.json',
 '/usr/local/sbin/lxc-magicdns','/etc/systemd/network/eth0.network',
 '/etc/systemd/system/lxc-magicdns.service','/etc/systemd/system/lxc-magicdns.timer']
paths += [str(p) for p in Path('/etc/systemd/resolved.conf.d').glob('*.conf')]
paths += [str(p) for p in Path('/etc/systemd/network/eth0.network.d').glob('*.conf')]
files={};dns={}
allowed={'DNS','FallbackDNS','Domains','DNSOverTLS','DNSSEC','DNSStubListener','DNSStubListenerExtra','LLMNR','MulticastDNS','DNSDefaultRoute'}
for name in paths:
 p=Path(name)
 if not p.exists() and not p.is_symlink():files[name]=None;continue
 info=p.lstat(); f={'link':os.readlink(p) if p.is_symlink() else None,'mode':stat.S_IMODE(info.st_mode),'uid':info.st_uid,'gid':info.st_gid}
 if p.is_file() and not p.is_symlink():
  data=p.read_bytes();f['sha256']=hashlib.sha256(data).hexdigest()
  if name=='/usr/local/sbin/lxc-magicdns' or name in ('/etc/systemd/system/lxc-magicdns.service','/etc/systemd/system/lxc-magicdns.timer'):f['sha256_sanitizado']=hashlib.sha256(san(data.decode()).encode()).hexdigest()
  if name=='/etc/systemd/network/eth0.network' or '/resolved.conf.d/' in name or '/eth0.network.d/' in name:
   dns[name]=[san(line.strip()) for line in data.decode().splitlines() if line.split('=',1)[0].strip() in allowed and '=' in line]
 files[name]=f
p=Path('/etc/docker/daemon.json');d=json.loads(p.read_text()) if p.exists() else {}
units={u:{c:run('systemctl',c,u) for c in ('is-active','is-enabled')} for u in ('lxc-magicdns.timer','lxc-magicdns.service','systemd-resolved','tailscaled','docker')}
print(json.dumps({'files':files,'dns':dns,'docker':{'keys':list(d),'dns':san(json.dumps(d.get('dns')))},
 'links':{str(p):os.readlink(p) for p in Path('/etc/systemd/system').rglob('lxc-magicdns*') if p.is_symlink()},
 'runtime':{link:{cmd:san(run('resolvectl',cmd,link)) for cmd in ('dns','domain','dnsovertls','default-route')} for link in ('eth0','tailscale0')},
 'units':units,'accept_dns':json.loads(run('tailscale','debug','prefs'))['CorpDNS']}))
