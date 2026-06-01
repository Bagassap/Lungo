import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'; USER = 'root'; PASS = 'Lungo09@Lungo67'
REMOTE_BASE = '/var/www/lungo-backend/backend'

def run(ssh, cmd, timeout=20):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

print("[PM2 Status]")
print(run(ssh, "pm2 show lungo-backend 2>/dev/null | grep -E 'status|pid|uptime|restart'"))

print("\n[Error log - last 40 lines]")
print(run(ssh, "pm2 logs lungo-backend --err --nostream --lines 40 2>/dev/null | tail -40"))

print("\n[Out log - last 20 lines]")
print(run(ssh, "pm2 logs lungo-backend --out --nostream --lines 20 2>/dev/null | tail -20"))

print("\n[Direct node test]")
print(run(ssh, f"cd {REMOTE_BASE} && timeout 10 node dist/main.js 2>&1 | head -30", timeout=15))

print("\n[Check if main.js has helmet]")
print(run(ssh, f"head -5 {REMOTE_BASE}/dist/main.js"))

print("\n[node_modules/helmet exists?]")
print(run(ssh, f"ls {REMOTE_BASE}/node_modules/helmet/package.json 2>/dev/null && echo YES || echo NO"))

print("\n[node_modules/@nestjs/throttler?]")
print(run(ssh, f"ls {REMOTE_BASE}/node_modules/@nestjs/throttler/package.json 2>/dev/null && echo YES || echo NO"))

print("\n[.env JWT_EXPIRES_IN]")
print(run(ssh, f"grep -E 'JWT_EXPIRES_IN|REDIS' {REMOTE_BASE}/.env 2>/dev/null"))

ssh.close()
