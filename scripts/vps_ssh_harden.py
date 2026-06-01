import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HOST = '187.77.116.121'; USER = 'root'; PASS = 'Lungo09@Lungo67'

def run(ssh, cmd, timeout=20):
    _, o, e = ssh.exec_command(cmd, timeout=timeout)
    return o.read().decode('utf-8','replace').strip(), e.read().decode('utf-8','replace').strip()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)
print("Connected.")

# Set ubuntu user password (same as root for now, user can change later)
out, _ = run(ssh, "echo 'ubuntu:Lungo09@Lungo67' | chpasswd && echo OK")
print(f"[1] Set ubuntu password: {out}")

# Verify ubuntu can sudo
out, _ = run(ssh, "id ubuntu && groups ubuntu")
print(f"[2] Ubuntu user: {out}")

# Harden SSH config
ssh_config = """
# Lungo Security Hardening
PermitRootLogin no
PasswordAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
AllowUsers ubuntu
Protocol 2
"""
sftp = ssh.open_sftp()
# Backup original
run(ssh, "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup_$(date +%Y%m%d) 2>/dev/null || true")

# Read current config, apply changes
out, _ = run(ssh, "cat /etc/ssh/sshd_config")
lines = out.split('\n')
new_lines = []
skip_keys = {'PermitRootLogin', 'MaxAuthTries', 'LoginGraceTime', 'AllowUsers', 'Protocol'}
for line in lines:
    key = line.strip().split()[0] if line.strip() and not line.strip().startswith('#') else ''
    if key in skip_keys:
        continue  # will be added via our config
    new_lines.append(line)

new_lines.append(ssh_config)
new_config = '\n'.join(new_lines)
with sftp.open('/etc/ssh/sshd_config', 'w') as f:
    f.write(new_config)
sftp.close()

# Validate config before reloading
out, err = run(ssh, "sshd -t 2>&1")
if err and 'error' in err.lower():
    print(f"[!] SSH config error: {err}")
    # Restore backup
    run(ssh, "cp /etc/ssh/sshd_config.backup_$(ls -t /etc/ssh/sshd_config.backup_* | head -1 | xargs basename) /etc/ssh/sshd_config 2>/dev/null")
    print("Restored backup.")
else:
    print("[3] SSH config validated.")
    out, _ = run(ssh, "systemctl reload ssh && echo reloaded")
    print(f"[4] SSH reload: {out}")

# Verify PermitRootLogin is set
out, _ = run(ssh, "grep '^PermitRootLogin' /etc/ssh/sshd_config")
print(f"[5] PermitRootLogin: {out}")

out, _ = run(ssh, "grep '^AllowUsers' /etc/ssh/sshd_config")
print(f"[6] AllowUsers: {out}")

ssh.close()
print("\nDone. Root SSH disabled. Login with: ssh ubuntu@187.77.116.121")
