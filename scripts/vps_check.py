import paramiko
import sys

HOST = '187.77.116.121'
USER = 'root'
PASS = 'Lungo09@Lungo67'

def run(ssh, cmd):
    _, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    return out, err

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=15)
    print("=== Connected to VPS ===")

    # Check users with real login shells
    out, _ = run(ssh, "getent passwd | awk -F: '$7 !~ /nologin|false/ {print $1, $3}' | sort -t' ' -k2 -n")
    print("\n=== Users with login shells ===")
    print(out)

    # Check existing sudo users
    out2, _ = run(ssh, "getent group sudo | cut -d: -f4")
    print(f"\n=== Sudo group members ===\n{out2}")

    # Check UFW status
    out3, _ = run(ssh, "ufw status 2>/dev/null || echo 'UFW not installed'")
    print(f"\n=== UFW status ===\n{out3}")

    # Check fail2ban
    out4, _ = run(ssh, "which fail2ban-client 2>/dev/null && echo 'installed' || echo 'not installed'")
    print(f"\n=== fail2ban ===\n{out4}")

    # Check PM2 processes
    out5, _ = run(ssh, "pm2 list --no-color 2>/dev/null | head -20")
    print(f"\n=== PM2 processes ===\n{out5}")

    # Check nginx version visibility
    out6, _ = run(ssh, "nginx -v 2>&1; nginx -T 2>/dev/null | grep 'server_tokens' | head -3")
    print(f"\n=== Nginx ===\n{out6}")

    ssh.close()

if __name__ == '__main__':
    main()
