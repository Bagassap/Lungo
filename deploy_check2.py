# -*- coding: utf-8 -*-
import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('187.77.116.121', username='root', password='Lungo09@Lungo67', timeout=15)

stdin, stdout, stderr = ssh.exec_command('pm2 status 2>&1')
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
