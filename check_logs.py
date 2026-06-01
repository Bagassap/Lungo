import paramiko

HOST = '187.77.116.121'
USER = 'root'
PASS = 'Lungo09@Lungo67'

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

# Check error logs
stdin, stdout, stderr = ssh.exec_command('pm2 logs lungo-backend --err --nostream --lines 60 2>&1')
out = stdout.read().decode('utf-8', errors='replace')
print('=== PM2 ERROR LOGS ===')
print(out[:4000])

# Check process status
stdin2, stdout2, stderr2 = ssh.exec_command('pm2 status 2>&1')
out2 = stdout2.read().decode('utf-8', errors='replace')
print('\n=== PM2 STATUS ===')
print(out2[:2000])

ssh.close()
