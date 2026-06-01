import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
HOST='187.77.116.121'; USER='ubuntu'; PASS='Lungo09@Lungo67'

def run(ssh, cmd, timeout=30):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip(), e.read().decode('utf-8','replace').strip()

def sudo(ssh, cmd, timeout=30):
    return run(ssh, f'echo "{PASS}" | sudo -S {cmd} 2>&1', timeout)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)
print("Connected.")

# ── 1. Cek apakah Nginx sudah ada ──────────────────────────────────────────
print("\n[1] Cek Nginx ...")
out, _ = run(ssh, 'nginx -v 2>&1 || echo NOT_INSTALLED')
print(f"  {out}")
if 'NOT_INSTALLED' in out:
    print("  Installing Nginx ...")
    out, _ = sudo(ssh, 'apt-get install -y nginx 2>&1 | tail -3', timeout=120)
    print(out)

# ── 2. Cek konfigurasi Nginx existing ──────────────────────────────────────
print("\n[2] Cek existing Nginx config ...")
out, _ = run(ssh, 'ls /etc/nginx/sites-enabled/ 2>/dev/null')
print(f"  sites-enabled: {out}")
out, _ = run(ssh, 'cat /etc/nginx/sites-enabled/default 2>/dev/null | head -20')
print(f"  default: {out[:300]}")

# ── 3. Buat Nginx config untuk Lungo ───────────────────────────────────────
print("\n[3] Deploy Nginx config ...")
nginx_config = '''server {
    listen 80;
    server_name 187.77.116.121 _;

    # Sembunyikan versi server
    server_tokens off;
    more_clear_headers Server;

    # Blokir akses ke Swagger
    location = /api {
        return 403 '{"statusCode":403,"message":"Akses ditolak."}';
        add_header Content-Type application/json;
    }
    location ^~ /api/ {
        return 403 '{"statusCode":403,"message":"Akses ditolak."}';
        add_header Content-Type application/json;
    }

    # Blokir file berbahaya
    location ~* \\.(php|asp|aspx|jsp|cgi|sh)$ {
        return 403;
    }

    # Semua request → NestJS
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

        # Hapus header sensitif dari response
        proxy_hide_header X-Powered-By;
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options DENY always;
    }
}
'''

sftp = ssh.open_sftp()
with sftp.open('/tmp/lungo-nginx.conf', 'w') as f:
    f.write(nginx_config)
sftp.close()

out, _ = sudo(ssh, 'cp /tmp/lungo-nginx.conf /etc/nginx/sites-available/lungo')
out, _ = sudo(ssh, 'ln -sf /etc/nginx/sites-available/lungo /etc/nginx/sites-enabled/lungo')
# Disable default site
sudo(ssh, 'rm -f /etc/nginx/sites-enabled/default')
print("  Config deployed.")

# ── 4. Test Nginx config ───────────────────────────────────────────────────
print("\n[4] Test Nginx config ...")
out, _ = sudo(ssh, 'nginx -t 2>&1')
print(f"  {out}")

if 'successful' in out or 'ok' in out.lower():
    print("  Reload Nginx ...")
    sudo(ssh, 'systemctl reload nginx')
    time.sleep(2)
else:
    print("  [!] Config error! Tidak reload.")

# ── 5. UFW: blokir port 3000 dari luar ────────────────────────────────────
print("\n[5] UFW: blokir port 3000 dari publik ...")
# Hapus rule lama yang allow 3000 dari mana saja
sudo(ssh, 'ufw delete allow 3000/tcp 2>/dev/null || true')
# Izinkan HANYA dari localhost
sudo(ssh, "ufw allow from 127.0.0.1 to any port 3000")
out, _ = sudo(ssh, 'ufw status')
print(out)

# ── 6. Test via port 80 (Nginx) ────────────────────────────────────────────
print("\n[6] Test via Nginx (port 80) ...")
health = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost/health")[0]
api_block = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost/api")[0]
headers = run(ssh, "curl -si http://localhost/health 2>/dev/null | grep -iE 'x-frame|x-content|server' | head -5")[0]
print(f"  /health → {health}  (target: 200)")
print(f"  /api    → {api_block}  (target: 403)")
print(f"  Headers:\n{headers}")

# ── 7. Test port 3000 dari luar (harus ditolak) ────────────────────────────
print("\n[7] Port 3000 hanya dari localhost ...")
out = run(ssh, "ufw status | grep 3000")[0]
print(f"  UFW 3000: {out}")

ssh.close()
print("\n=== Nginx setup selesai ===")
