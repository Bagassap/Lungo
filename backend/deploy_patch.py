import paramiko, sys, time

host = '187.77.116.121'
user = 'ubuntu'
password = 'Lungo09@Lungo67'
remote = '/var/www/lungo-backend/backend'

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(host, username=user, password=password)

# Upload file yang diubah: tracking.gateway.ts + fcm.service.ts
sftp = ssh.open_sftp()
sftp.put('src/tracking/tracking.gateway.ts',
         f'{remote}/src/tracking/tracking.gateway.ts')
sftp.put('src/booking/fcm.service.ts',
         f'{remote}/src/booking/fcm.service.ts')
sftp.close()
print('Upload selesai')

# Build di VPS
_, out, err = ssh.exec_command(
    f'cd {remote} && npm run build 2>&1 | tail -10')
out.channel.recv_exit_status()
print(out.read().decode('utf-8', errors='replace'))

# Restart PM2
ssh.exec_command('pm2 restart lungo-backend')
time.sleep(5)

# Health check
_, out, _ = ssh.exec_command(
    'curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health')
print('Health:', out.read().decode())
ssh.close()
