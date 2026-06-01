# -*- coding: utf-8 -*-
import paramiko
import sys

sys.stdout.reconfigure(encoding='utf-8')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('187.77.116.121', username='root', password='Lungo09@Lungo67', timeout=15)

stdin, stdout, stderr = ssh.exec_command('pm2 list 2>&1 && echo "==ROOT==" && ls /root/ && echo "==VAR-WWW==" && ls /var/www/ 2>/dev/null || echo no-www')
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print(out)
if err:
    print("STDERR:", err)
ssh.close()
