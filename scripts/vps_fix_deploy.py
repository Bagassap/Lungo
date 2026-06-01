import paramiko, os, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'; USER = 'root'; PASS = 'Lungo09@Lungo67'
REMOTE_BASE = '/var/www/lungo-backend/backend'

def run(ssh, cmd, timeout=120):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    out = o.read().decode('utf-8','replace').strip()
    err = e.read().decode('utf-8','replace').strip()
    return out, err

def upload_dir(ssh, local_dir, remote_dir):
    sftp = ssh.open_sftp()
    def _mkdir_p(sftp, path):
        parts = path.split('/')
        cur = ''
        for part in parts:
            if not part: continue
            cur += '/' + part
            try: sftp.mkdir(cur)
            except: pass
    def _upload(local, remote):
        _mkdir_p(sftp, remote)
        for item in os.listdir(local):
            lp = os.path.join(local, item)
            rp = remote + '/' + item
            if os.path.isdir(lp): _upload(lp, rp)
            else: sftp.put(lp, rp)
    _upload(local_dir, remote_dir)
    sftp.close()
    print(f"  Uploaded -> {remote_dir}")

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=15)
    print(f"Connected. Deploying to {REMOTE_BASE}")

    # ── 1. Upload dist to correct location ──────────────────────────────────
    print("\n[1] Uploading dist/ to correct path ...")
    local_dist = r'c:\laragon\www\LUNGO\backend\dist'
    out, _ = run(ssh, f'rm -rf {REMOTE_BASE}/dist && echo done')
    print(f"  rm old dist: {out}")
    upload_dir(ssh, local_dist, f'{REMOTE_BASE}/dist')

    # ── 2. Install missing packages ──────────────────────────────────────────
    print("\n[2] Installing helmet + @nestjs/throttler ...")
    out, err = run(ssh, f'cd {REMOTE_BASE} && npm install helmet @nestjs/throttler --save 2>&1 | tail -5', timeout=120)
    print(out or err)

    # ── 3. Update .env with CORS_ORIGINS ─────────────────────────────────────
    print("\n[3] Updating .env ...")
    # Read existing .env
    out, _ = run(ssh, f'cat {REMOTE_BASE}/.env 2>/dev/null')
    lines = [l for l in out.split('\n') if l and not l.startswith('CORS_ORIGINS')]
    lines.append('CORS_ORIGINS=http://187.77.116.121,https://187.77.116.121')
    new_env = '\n'.join(lines) + '\n'

    sftp = ssh.open_sftp()
    with sftp.open(f'{REMOTE_BASE}/.env', 'w') as f:
        f.write(new_env)
    sftp.close()
    out, _ = run(ssh, f'grep -E "CORS_ORIGINS|JWT_EXPIRES_IN|JWT_SECRET" {REMOTE_BASE}/.env | head -5')
    print(out)

    # ── 4. PM2 restart ───────────────────────────────────────────────────────
    print("\n[4] Restarting PM2 ...")
    out, err = run(ssh, 'pm2 restart lungo-backend --update-env 2>&1 | tail -3')
    print(out or err)

    # Wait for process to start
    import time; time.sleep(5)
    out, _ = run(ssh, 'pm2 show lungo-backend 2>/dev/null | grep -E "status|pid|uptime"')
    print(out)

    # ── 5. Smoke test ────────────────────────────────────────────────────────
    print("\n[5] Smoke test ...")
    out, _ = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health")
    print(f"  /health: {out}")
    out, _ = run(ssh, "curl -s -I http://localhost:3000/health | grep -iE 'x-content|x-frame|x-xss|referrer'")
    print(f"  Security headers:\n{out}")

    # ── 6. Check PM2 errors ──────────────────────────────────────────────────
    print("\n[6] PM2 error log (last 10 lines) ...")
    out, _ = run(ssh, 'pm2 logs lungo-backend --err --nostream --lines 10 2>/dev/null | tail -10')
    print(out)

    ssh.close()
    print("\n=== Deploy complete ===")

if __name__ == '__main__':
    main()
