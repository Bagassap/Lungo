import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'; USER = 'root'; PASS = 'Lungo09@Lungo67'
REMOTE_BASE = '/var/www/lungo-backend/backend'

def run(ssh, cmd, timeout=20):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

# Read local .env
with open(r'c:\laragon\www\LUNGO\backend\.env', 'r') as f:
    local_env = f.read()

# Read VPS .env
vps_env = run(ssh, f'cat {REMOTE_BASE}/.env 2>/dev/null')

# Merge: start with local .env as base, keep VPS values for DB/Redis/Firebase
# Keys that should come from VPS (infra-specific)
vps_keep = ['DB_HOST','DB_PORT','DB_USERNAME','DB_PASSWORD','DB_NAME',
            'REDIS_HOST','REDIS_PORT','FIREBASE_PROJECT_ID',
            'ZENZIVA_USER','ZENZIVA_API_KEY','PORT']

local_lines = {l.split('=')[0]: l for l in local_env.splitlines() if '=' in l and not l.startswith('#')}
vps_lines   = {l.split('=')[0]: l for l in vps_env.splitlines()   if '=' in l and not l.startswith('#')}

merged = dict(local_lines)
for k in vps_keep:
    if k in vps_lines:
        merged[k] = vps_lines[k]

# Ensure CORS_ORIGINS is set
merged['CORS_ORIGINS'] = 'CORS_ORIGINS=http://187.77.116.121,https://187.77.116.121'
# Set new JWT TTLs
merged['JWT_EXPIRES_IN'] = 'JWT_EXPIRES_IN=15m'
merged['JWT_REFRESH_EXPIRES_IN'] = 'JWT_REFRESH_EXPIRES_IN=7d'

new_env = '\n'.join(merged.values()) + '\n'

sftp = ssh.open_sftp()
with sftp.open(f'{REMOTE_BASE}/.env', 'w') as f:
    f.write(new_env)
sftp.close()

print("Updated .env. Key values:")
for k in ['JWT_EXPIRES_IN','JWT_REFRESH_EXPIRES_IN','CORS_ORIGINS']:
    if k in merged:
        print(f"  {merged[k]}")

# Restart
run(ssh, 'pm2 restart lungo-backend --update-env 2>&1')
import time; time.sleep(5)
out = run(ssh, 'pm2 show lungo-backend 2>/dev/null | grep -E "status|uptime"')
print(f"\nPM2: {out}")
out = run(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health")
print(f"Health: {out}")
ssh.close()
