# -*- coding: utf-8 -*-
import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')

HOST = '187.77.116.121'
USER = 'root'
PASS = 'Lungo09@Lungo67'
REMOTE_BASE = '/var/www/lungo-backend/backend'

FILES = {
    r'c:\laragon\www\LUNGO\backend\src\auth\auth.service.ts':                    f'{REMOTE_BASE}/src/auth/auth.service.ts',
    r'c:\laragon\www\LUNGO\backend\src\auth\auth.controller.ts':                 f'{REMOTE_BASE}/src/auth/auth.controller.ts',
    r'c:\laragon\www\LUNGO\backend\src\auth\dto\select-role.dto.ts':             f'{REMOTE_BASE}/src/auth/dto/select-role.dto.ts',
    r'c:\laragon\www\LUNGO\backend\src\auth\dto\complete-registration.dto.ts':   f'{REMOTE_BASE}/src/auth/dto/complete-registration.dto.ts',
    r'c:\laragon\www\LUNGO\backend\src\auth\dto\send-otp.dto.ts':                f'{REMOTE_BASE}/src/auth/dto/send-otp.dto.ts',
}

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)
sftp = ssh.open_sftp()

# Pastikan dir dto ada
ssh.exec_command(f'mkdir -p {REMOTE_BASE}/src/auth/dto')
import time as t; t.sleep(1)

print("=== UPLOAD FILES ===")
for local, remote in FILES.items():
    sftp.put(local, remote)
    print(f"  OK: {remote}")
sftp.close()

def run(cmd, label=''):
    print(f"\n=== {label or cmd} ===")
    stdin, stdout, stderr = ssh.exec_command(cmd, get_pty=False)
    stdout.channel.settimeout(90)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    if out: print(out)
    if err: print("STDERR:", err)
    return out

run(f'cd {REMOTE_BASE} && npm run build 2>&1', 'NPM BUILD')
run('pm2 restart lungo-backend --update-env 2>&1', 'PM2 RESTART')

print("\n--- tunggu 4 detik ---")
time.sleep(4)
run('pm2 status 2>&1', 'PM2 STATUS')
ssh.close()
print("\nDeploy selesai.")
