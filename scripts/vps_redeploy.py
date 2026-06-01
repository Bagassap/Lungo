import paramiko, os, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'; USER = 'root'; PASS = 'Lungo09@Lungo67'
REMOTE_BASE = '/var/www/lungo-backend/backend'

def run(ssh, cmd, timeout=60):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip(), e.read().decode('utf-8','replace').strip()

def upload_dir(ssh, local_dir, remote_dir):
    sftp = ssh.open_sftp()
    def _mkdir_p(path):
        parts = path.split('/')
        cur = ''
        for part in parts:
            if not part: continue
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
print("[1] Uploading fixed dist/ ...")
run(ssh, f'rm -rf {REMOTE_BASE}/dist')
upload_dir(ssh, r'c:\laragon\www\LUNGO\backend\dist', f'{REMOTE_BASE}/dist')
print("  Done.")

# Restart PM2
print("[2] PM2 restart ...")
out, _ = run(ssh, 'pm2 restart lungo-backend --update-env 2>&1 | tail -2')
print(out)

# Wait and check
time.sleep(8)

out, _ = run(ssh, 'pm2 show lungo-backend 2>/dev/null | grep -E "status|uptime|restarts"')
print(f"[3] PM2 status:\n{out}")

# Smoke test headers
print("[4] Security headers smoke test:")
out, _ = run(ssh, "curl -si http://localhost:3000/health | head -20")
print(out)

# Check for errors
out, _ = run(ssh, 'pm2 logs lungo-backend --err --nostream --lines 5 2>/dev/null | tail -5')
print(f"[5] Recent errors:\n{out}")

ssh.close()
