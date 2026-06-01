import paramiko
import os, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'
USER = 'root'
PASS = 'Lungo09@Lungo67'

def run(ssh, cmd, timeout=30):
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    return out, err

def upload_dir(ssh, local_dir, remote_dir):
    sftp = ssh.open_sftp()
    def _upload(local, remote):
        try:
            sftp.mkdir(remote)
        except Exception:
            pass
        for item in os.listdir(local):
            lpath = os.path.join(local, item)
            rpath = remote + '/' + item
            if os.path.isdir(lpath):
                _upload(lpath, rpath)
            else:
                sftp.put(lpath, rpath)
    _upload(local_dir, remote_dir)
    sftp.close()
    print(f"  Uploaded {local_dir} -> {remote_dir}")

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=15)
    print("=== Connected to VPS ===")

    # ── 1. Deploy backend ───────────────────────────────────────────────────
    print("\n[1/4] Deploying backend dist/ ...")
    local_dist = r'c:\laragon\www\LUNGO\backend\dist'
    remote_dist = '/root/lungo-backend/dist'
    out, _ = run(ssh, 'ls /root/lungo-backend/ 2>/dev/null || echo "missing"')
    if 'missing' in out:
        run(ssh, 'mkdir -p /root/lungo-backend')

    # Upload new dist (only if it changed — rm + re-upload is safe)
    run(ssh, 'rm -rf /root/lungo-backend/dist')
    upload_dir(ssh, local_dist, remote_dist)

    # ── 2. Restart PM2 ─────────────────────────────────────────────────────
    print("\n[2/4] Restarting PM2 ...")
    out, err = run(ssh, 'cd /root/lungo-backend && pm2 restart lungo-backend --update-env 2>&1 || pm2 start dist/main.js --name lungo-backend 2>&1')
    print(out[-500:] if out else err[-300:])

    # ── 3. UFW hardening ────────────────────────────────────────────────────
    print("\n[3/4] Setting up UFW firewall ...")
    cmds = [
        'ufw --force reset',
        'ufw default deny incoming',
        'ufw default allow outgoing',
        'ufw allow 22/tcp',
        'ufw allow 80/tcp',
        'ufw allow 443/tcp',
        'ufw allow 3000/tcp',
        'ufw --force enable',
        'ufw status verbose',
    ]
    for cmd in cmds:
        out, err = run(ssh, cmd)
        print(f"  $ {cmd}")
        if out: print(f"    {out[:200]}")

    # ── 4. Install & configure fail2ban ─────────────────────────────────────
    print("\n[4/4] Installing fail2ban ...")
    out, err = run(ssh, 'apt-get install -y fail2ban 2>&1 | tail -5', timeout=120)
    print(out[-300:])

    # Configure fail2ban for SSH
    jail_local = '''[DEFAULT]
bantime  = 1800
findtime = 300
maxretry = 5
backend  = auto

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 3600
'''
    sftp = ssh.open_sftp()
    with sftp.open('/etc/fail2ban/jail.local', 'w') as f:
        f.write(jail_local)
    sftp.close()

    run(ssh, 'systemctl enable fail2ban && systemctl restart fail2ban')
    out, _ = run(ssh, 'systemctl is-active fail2ban')
    print(f"  fail2ban status: {out}")

    # ── Hide Nginx version ─────────────────────────────────────────────────
    out, _ = run(ssh, "which nginx 2>/dev/null && echo yes || echo no")
    if 'yes' in out:
        run(ssh, "sed -i '/server_tokens/d' /etc/nginx/nginx.conf; sed -i '/http {/a\\\\tserver_tokens off;' /etc/nginx/nginx.conf")
        run(ssh, "nginx -t && systemctl reload nginx 2>/dev/null || true")
        print("  Nginx: server_tokens off")

    # ── Final status ───────────────────────────────────────────────────────
    print("\n=== Final Status ===")
    out, _ = run(ssh, 'pm2 list --no-color 2>&1')
    print(out[:600])
    out, _ = run(ssh, 'ufw status')
    print(out[:400])
    out, _ = run(ssh, 'fail2ban-client status 2>&1')
    print(out[:200])

    ssh.close()
    print("\n=== Deploy complete ===")

if __name__ == '__main__':
    main()
