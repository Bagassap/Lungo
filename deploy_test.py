# -*- coding: utf-8 -*-
import paramiko, sys, time, urllib.request, json
sys.stdout.reconfigure(encoding='utf-8')

# Test send-otp — lihat apakah OTP muncul di response
print("=== TEST SEND-OTP (cek SHOW_OTP) ===")
try:
    data = json.dumps({"phone": "085640168132"}).encode('utf-8')
    req = urllib.request.Request(
        'http://187.77.116.121:3000/auth/send-otp',
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read().decode('utf-8')
        print(f"HTTP {resp.status}: {body}")
except Exception as e:
    print(f"Error: {e}")

# PM2 logs
print("\n=== PM2 LOGS ===")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('187.77.116.121', username='root', password='Lungo09@Lungo67', timeout=15)
time.sleep(2)
stdin, stdout, stderr = ssh.exec_command('pm2 logs lungo-backend --lines 10 --nostream 2>&1')
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
