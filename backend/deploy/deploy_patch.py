import paramiko
import os
import sys
import tarfile
import tempfile

HOST = "187.77.116.121"
PORT = 22
USER = "root"
PASSWORD = "Lungo09@Lungo67"
REMOTE_APP_DIR = "/var/www/lungo-backend"
LOCAL_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

UPLOAD_FILES = [
    ("dist", f"{REMOTE_APP_DIR}/dist"),
    ("package.json", f"{REMOTE_APP_DIR}/package.json"),
    ("package-lock.json", f"{REMOTE_APP_DIR}/package-lock.json"),
]

def create_tarball(local_base):
    tmp = tempfile.mktemp(suffix=".tar.gz")
    with tarfile.open(tmp, "w:gz") as tar:
        dist_path = os.path.join(local_base, "dist")
        tar.add(dist_path, arcname="dist")
        tar.add(os.path.join(local_base, "package.json"), arcname="package.json")
        pkg_lock = os.path.join(local_base, "package-lock.json")
        if os.path.exists(pkg_lock):
            tar.add(pkg_lock, arcname="package-lock.json")
    return tmp

def run(client, cmd, print_output=True):
    print(f"  $ {cmd}")
    _, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    if print_output and out:
        print(f"    {out}")
    if err:
        print(f"  [stderr] {err}", file=sys.stderr)
    return out

def main():
    print("=== LUNGO VPS DEPLOY ===")
    print(f"Target: {USER}@{HOST}:{REMOTE_APP_DIR}\n")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    print("[1/4] Connecting to VPS...")
    client.connect(HOST, PORT, USER, PASSWORD, timeout=30)
    print("      Connected OK")

    print("[2/4] Creating tarball of dist + package.json...")
    tarball = create_tarball(LOCAL_BASE)
    print(f"      Tarball: {tarball}")

    print("[3/4] Uploading via SFTP...")
    sftp = client.open_sftp()
    remote_tar = f"{REMOTE_APP_DIR}/deploy_patch.tar.gz"
    run(client, f"mkdir -p {REMOTE_APP_DIR}")
    sftp.put(tarball, remote_tar)
    sftp.close()
    os.unlink(tarball)
    print("      Upload OK")

    print("[4/4] Extracting + restarting on VPS...")
    run(client, f"cd {REMOTE_APP_DIR} && tar -xzf deploy_patch.tar.gz && rm deploy_patch.tar.gz")
    run(client, f"cd {REMOTE_APP_DIR} && npm install --production --silent")
    run(client, "pm2 restart lungo-backend || pm2 start /var/www/lungo-backend/dist/main.js --name lungo-backend")
    run(client, "pm2 save")

    print("\n[HEALTH CHECK]")
    out = run(client, "curl -sf http://localhost:3000/health || echo 'health check failed'")
    print(f"  Result: {out}")

    client.close()
    print("\n=== DEPLOY DONE ===")

if __name__ == "__main__":
    main()
