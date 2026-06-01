import paramiko, os, sys
sys.stdout.reconfigure(encoding='utf-8')

HOST = '187.77.116.121'
USER = 'root'
PASS = 'Lungo09@Lungo67'
LOCAL_DIST  = r'c:\laragon\www\LUNGO\backend\dist'
REMOTE_DIST = '/var/www/lungo-backend/backend/dist'

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)
sftp = ssh.open_sftp()

def run(cmd, label=''):
    label = label or cmd[:60]
    _, stdout, stderr = ssh.exec_command(cmd, get_pty=False)
    stdout.channel.settimeout(60)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if out: print(f'[{label}] {out[:400]}')
    if err and 'warn' not in err.lower(): print(f'[{label}] ERR: {err[:200]}')
    return out

# Upload all JS files recursively
print('=== UPLOADING dist/ ===')
count = 0
for root, dirs, files in os.walk(LOCAL_DIST):
    for fname in files:
        if not fname.endswith('.js'):
            continue
        local_path  = os.path.join(root, fname)
        rel_path    = os.path.relpath(local_path, LOCAL_DIST).replace('\\', '/')
        remote_path = f'{REMOTE_DIST}/{rel_path}'

        # Ensure remote dir exists
        remote_dir  = remote_path.rsplit('/', 1)[0]
        ssh.exec_command(f'mkdir -p "{remote_dir}"')

        sftp.put(local_path, remote_path)
        count += 1
        if count <= 10 or count % 50 == 0:
            print(f'  [{count}] {rel_path}')

sftp.close()
print(f'\n  Total: {count} files uploaded')

# PM2 restart
print('\n=== RESTARTING PM2 ===')
run('pm2 restart lungo-backend', 'PM2-restart')
import time; time.sleep(3)
run('pm2 status 2>&1 | grep lungo', 'PM2-status')

# Quick smoke tests
print('\n=== SMOKE TESTS ===')
run('curl -s http://localhost:3000/health', 'health')
run('curl -s http://localhost:3000/tariff/info', 'tariff')

print('\nDeploy complete!')
