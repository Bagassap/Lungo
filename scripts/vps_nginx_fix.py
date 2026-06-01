import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
HOST='187.77.116.121'; USER='ubuntu'; PASS='Lungo09@Lungo67'

def run(ssh, cmd, timeout=30):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip()

def sudo(ssh, cmd, timeout=30):
    return run(ssh, f'echo "{PASS}" | sudo -S bash -c \'{cmd}\' 2>&1', timeout)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)
print("Connected.")

# ── 1. Tambahkan server_tokens off ke nginx.conf ────────────────────────────
print("\n[1] server_tokens off ke nginx.conf ...")
# Check if already set
current = run(ssh, 'grep server_tokens /etc/nginx/nginx.conf')
print(f"  Current: {current}")
if 'off' not in current:
    sudo(ssh, r"sed -i '/http {/a\\\\tserver_tokens off;' /etc/nginx/nginx.conf")
    print("  Added server_tokens off.")

# ── 2. Deploy fixed Nginx site config (tanpa more_clear_headers) ───────────
print("\n[2] Deploy fixed Lungo Nginx config ...")
nginx_config = r'''server {
    listen 80;
    server_name 187.77.116.121 _;

    # Blokir akses langsung ke Swagger
    location = /api {
        return 403 '{"statusCode":403,"message":"Akses ditolak."}';
        add_header Content-Type application/json always;
    }
    location ^~ /api/ {
        return 403 '{"statusCode":403,"message":"Akses ditolak."}';
        add_header Content-Type application/json always;
    }

    # Blokir file berbahaya
    location ~* \.(php|asp|aspx|jsp|cgi|sh)$ {
        return 403;
    }

    # Semua request → NestJS (port 3000)
    location / {
        proxy_pass          http://127.0.0.1:3000;
        proxy_http_version  1.1;
        proxy_set_header    Upgrade $http_upgrade;
        proxy_set_header    Connection "upgrade";
        proxy_set_header    Host $host;
        proxy_set_header    X-Real-IP $remote_addr;
        proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto $scheme;
        proxy_cache_bypass  $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
        proxy_hide_header     X-Powered-By;
    }
}
'''

sftp = ssh.open_sftp()
with sftp.open('/tmp/lungo-nginx.conf', 'w') as f:
    f.write(nginx_config)
sftp.close()

run(ssh, f'echo "{PASS}" | sudo -S cp /tmp/lungo-nginx.conf /etc/nginx/sites-available/lungo')
run(ssh, f'echo "{PASS}" | sudo -S ln -sf /etc/nginx/sites-available/lungo /etc/nginx/sites-enabled/lungo')
run(ssh, f'echo "{PASS}" | sudo -S rm -f /etc/nginx/sites-enabled/default')
print("  Config written.")

# ── 3. Test & reload ─────────────────────────────────────────────────────
print("\n[3] Test & reload Nginx ...")
test = run(ssh, f'echo "{PASS}" | sudo -S nginx -t 2>&1')
print(f"  {test}")
if 'successful' in test or 'ok' in test.lower():
    run(ssh, f'echo "{PASS}" | sudo -S systemctl reload nginx 2>&1')
    time.sleep(2)
    print("  Reloaded.")
else:
    print("  [!] Config masih error!")
    print(run(ssh, 'cat /etc/nginx/sites-enabled/lungo'))

# ── 4. Smoke test via port 80 ─────────────────────────────────────────────
print("\n[4] Test via port 80 (Nginx) ...")
h = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost/health")
api = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost/api")
hdrs = run(ssh, "curl -sI http://localhost/health | grep -iE 'server:|x-content|x-frame|x-request|x-powered'")
print(f"  /health → {h}  (target: 200)")
print(f"  /api    → {api}  (target: 403)")
print(f"  Headers:\n{hdrs}")

# ── 5. Port 3000 test dari luar (UFW harus blokir) ────────────────────────
print("\n[5] UFW status port 3000 ...")
print(run(ssh, f'echo "{PASS}" | sudo -S ufw status | grep -E "3000|Status"'))

ssh.close()
print("\n=== Nginx fix selesai ===")
