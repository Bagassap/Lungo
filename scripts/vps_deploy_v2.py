import paramiko, os, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'
# Root SSH diblokir — gunakan ubuntu
USER = 'ubuntu'
PASS = 'Lungo09@Lungo67'
REMOTE_BASE = '/var/www/lungo-backend/backend'

def run(ssh, cmd, timeout=60):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    out = o.read().decode('utf-8', 'replace').strip()
    err = e.read().decode('utf-8', 'replace').strip()
    return out, err

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
    print(f"  Uploaded -> {remote_dir}")

def sudo_run(ssh, cmd, timeout=60):
    """Run command with sudo using password"""
    full = f'echo "{PASS}" | sudo -S {cmd} 2>&1'
    return run(ssh, full, timeout)

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(HOST, username=USER, password=PASS, timeout=15)
        print(f"Connected as {USER}")
    except Exception as e:
        print(f"ubuntu login failed: {e}. Trying root...")
        ssh.connect(HOST, username='root', password=PASS, timeout=15)
        print("Connected as root")

    # ── 1. Upload dist ────────────────────────────────────────────────────────
    print("\n[1] Upload dist/ ...")
    # Ubah ownership ke ubuntu agar bisa upload via SFTP
    run(ssh, f'sudo chown -R ubuntu:ubuntu {REMOTE_BASE} 2>/dev/null || true')
    run(ssh, f'sudo chmod -R 755 {REMOTE_BASE} 2>/dev/null || true')
    run(ssh, f'rm -rf {REMOTE_BASE}/dist && echo ok')
    run(ssh, f'mkdir -p {REMOTE_BASE}/dist')
    upload_dir(ssh, r'c:\laragon\www\LUNGO\backend\dist', f'{REMOTE_BASE}/dist')

    # ── 2. Install new packages on VPS ────────────────────────────────────────
    print("\n[2] Install hpp + uuid on VPS ...")
    out, err = run(ssh, f'cd {REMOTE_BASE} && npm install hpp uuid --save 2>&1 | tail -3', timeout=120)
    print(out or err)

    # ── 3. Set NODE_ENV=production in .env ───────────────────────────────────
    print("\n[3] Set NODE_ENV=production ...")
    out, _ = run(ssh, f'cat {REMOTE_BASE}/.env 2>/dev/null')
    lines = [l for l in out.split('\n') if l and not l.startswith('NODE_ENV')]
    lines.append('NODE_ENV=production')
    new_env = '\n'.join(lines) + '\n'
    sftp = ssh.open_sftp()
    with sftp.open(f'{REMOTE_BASE}/.env', 'w') as f:
        f.write(new_env)
    sftp.close()
    out, _ = run(ssh, f'grep NODE_ENV {REMOTE_BASE}/.env')
    print(f"  {out}")

    # ── 4. PM2 restart (via sudo — PM2 daemon milik root) ────────────────────
    print("\n[4] PM2 restart (sudo) ...")
    out, _ = run(ssh, f'echo "{PASS}" | sudo -S pm2 restart lungo-backend --update-env 2>&1 | tail -3')
    print(out)

    time.sleep(8)

    # ── 5. Smoke test ─────────────────────────────────────────────────────────
    print("\n[5] Smoke test ...")
    out, _ = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health")
    print(f"  /health → {out}")

    # Swagger harus 404 (NODE_ENV=production)
    out, _ = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api")
    print(f"  /api (Swagger) → {out}  (target: 404)")

    # Security headers
    out, _ = run(ssh, "curl -si http://localhost:3000/health | grep -iE 'x-content|x-frame|referrer|x-request|x-powered'")
    print(f"  Headers:\n{out}")

    # Check PM2 status
    out, _ = run(ssh, f'echo "{PASS}" | sudo -S pm2 show lungo-backend 2>/dev/null | grep -E "status|uptime|pid"')
    print(f"\n[6] PM2 status:\n{out}")

    ssh.close()
    print("\n=== Deploy selesai ===")

if __name__ == '__main__':
    main()
