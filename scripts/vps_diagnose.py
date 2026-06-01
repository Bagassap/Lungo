import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'; USER = 'root'; PASS = 'Lungo09@Lungo67'

def run(ssh, cmd, timeout=20):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

# Check if helmet is in node_modules
print("[1] helmet in node_modules?")
print(run(ssh, "ls /root/lungo-backend/node_modules/helmet 2>/dev/null && echo 'YES' || echo 'NO'"))

# Check main.js fingerprint (does it contain 'helmet'?)
print("\n[2] main.js contains 'helmet'?")
print(run(ssh, "grep -c 'helmet' /root/lungo-backend/dist/main.js 2>/dev/null || echo 'NOT FOUND'"))

# Check @nestjs/throttler
print("\n[3] throttler in node_modules?")
print(run(ssh, "ls /root/lungo-backend/node_modules/@nestjs/throttler 2>/dev/null && echo 'YES' || echo 'NO'"))

# Check what PM2 says about the script path
print("\n[4] PM2 info")
print(run(ssh, "pm2 show lungo-backend 2>/dev/null | grep -E 'script|cwd|status'"))

# Check PM2 logs for errors
print("\n[5] PM2 error log (last 20 lines)")
print(run(ssh, "pm2 logs lungo-backend --err --nostream --lines 20 2>/dev/null"))

# Check .env CORS_ORIGINS
print("\n[6] .env CORS_ORIGINS")
print(run(ssh, "grep 'CORS_ORIGINS' /root/lungo-backend/.env 2>/dev/null || echo 'NOT SET'"))

# Check main.js for our security markers
print("\n[7] main.js contains 'X-Content-Type-Options'?")
print(run(ssh, "grep -c 'X-Content-Type-Options' /root/lungo-backend/dist/main.js 2>/dev/null"))

ssh.close()
