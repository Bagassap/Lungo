import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
HOST='187.77.116.121'; USER='ubuntu'; PASS='Lungo09@Lungo67'
def run(ssh, cmd, timeout=20):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip()
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

print("[PM2 status]")
print(run(ssh, f'echo "{PASS}" | sudo -S pm2 show lungo-backend 2>/dev/null | grep -E "status|uptime|restart|pid path|script"'))

print("\n[PM2 error log - last 30 lines]")
print(run(ssh, f'echo "{PASS}" | sudo -S pm2 logs lungo-backend --err --nostream --lines 30 2>/dev/null | tail -30'))

print("\n[Port 3000 listening?]")
print(run(ssh, 'ss -tlnp | grep 3000 || echo "NOT LISTENING"'))

print("\n[Direct test]")
print(run(ssh, 'curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/health 2>/dev/null || echo "FAILED"'))

print("\n[NODE_ENV in PM2 env]")
print(run(ssh, f'echo "{PASS}" | sudo -S pm2 env 0 2>/dev/null | grep -E "NODE_ENV|PORT" | head -5'))

ssh.close()
