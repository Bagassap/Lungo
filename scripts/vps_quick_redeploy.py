import paramiko, os, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
HOST='187.77.116.121'; USER='ubuntu'; PASS='Lungo09@Lungo67'
REMOTE_BASE='/var/www/lungo-backend/backend'

def run(ssh, cmd, timeout=30):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip()

def upload_dir(ssh, local_dir, remote_dir):
    sftp = ssh.open_sftp()
    def _mkdir_p(path):
        parts = [p for p in path.split('/') if p]
        cur = ''
        for part in parts:
            cur += '/' + part
            try: sftp.mkdir(cur)
            except: pass
    def _upload(local, remote):
        _mkdir_p(remote)
        for item in os.listdir(local):
            lp = os.path.join(local, item)
            rp = remote + '/' + item
            if os.path.isdir(lp): _upload(lp, rp)
            else: sftp.put(lp, rp)
    _upload(local_dir, remote_dir)
    sftp.close()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)
print("Connected.")

# Upload new dist
print("[1] Upload dist/ ...")
run(ssh, f'rm -rf {REMOTE_BASE}/dist && mkdir -p {REMOTE_BASE}/dist')
upload_dir(ssh, r'c:\laragon\www\LUNGO\backend\dist', f'{REMOTE_BASE}/dist')
print("  Done.")

# PM2 restart
print("[2] PM2 restart ...")
out = run(ssh, f'echo "{PASS}" | sudo -S pm2 restart lungo-backend --update-env 2>&1 | tail -2')
print(out)
time.sleep(10)

# Status
print("[3] Status ...")
out = run(ssh, f'echo "{PASS}" | sudo -S pm2 show lungo-backend 2>/dev/null | grep -E "status|uptime|restart"')
print(out)

# Smoke tests
print("\n[4] Smoke tests ...")
h = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health")
api = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api")
print(f"  /health → {h}  (target: 200)")
print(f"  /api    → {api}  (target: 404)")

hdrs = run(ssh, "curl -si http://localhost:3000/health 2>/dev/null | grep -iE 'x-content|x-frame|referrer|x-powered|x-request'")
print(f"  Headers:\n{hdrs}")

# Error log
print("\n[5] Recent errors ...")
print(run(ssh, f'echo "{PASS}" | sudo -S pm2 logs lungo-backend --err --nostream --lines 5 2>/dev/null | tail -5'))

ssh.close()
