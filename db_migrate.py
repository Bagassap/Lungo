import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8')

HOST = '187.77.116.121'
USER = 'root'
PASS = 'Lungo09@Lungo67'
DB_USER = 'lungo_user'
DB_PASS = 'LungoDB2025!'
DB_NAME = 'lungo_db'
PSQL = f'PGPASSWORD="{DB_PASS}" psql -h localhost -p 5432 -U {DB_USER} -d {DB_NAME}'

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

def run(cmd, label=''):
    label = label or cmd[:60]
    _, stdout, stderr = ssh.exec_command(cmd, get_pty=False)
    stdout.channel.settimeout(30)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if out: print(f'[{label}] {out}')
    if err and 'NOTICE' not in err: print(f'[{label}] ERR: {err[:300]}')
    return out

def sql(query, label=''):
    return run(f'{PSQL} -c "{query}"', label or query[:50])

print('=== MIGRATION: rides.passengerRating ===')
sql(
    "ALTER TABLE rides ADD COLUMN IF NOT EXISTS \\\"passengerRating\\\" integer DEFAULT NULL;",
    'ADD passengerRating'
)

print('\n=== MIGRATION: wallet_transactions column rename ===')
# Check actual column names first
res = run(f'{PSQL} -c "SELECT column_name FROM information_schema.columns WHERE table_name=\'wallet_transactions\' ORDER BY ordinal_position;"', 'wallet-cols')
print(res)

# If columns are lowercase, rename them to camelCase
# PostgreSQL: ALTER TABLE ... RENAME COLUMN old TO new;
for old_col, new_col in [
    ('userid', 'userId'),
    ('balanceafter', 'balanceAfter'),
    ('rideid', 'rideId'),
    ('createdat', 'createdAt'),
]:
    sql(
        f'ALTER TABLE wallet_transactions RENAME COLUMN {old_col} TO \\"{new_col}\\";',
        f'rename {old_col} -> {new_col}'
    )

print('\n=== VERIFY: rides columns ===')
sql(
    "SELECT column_name FROM information_schema.columns WHERE table_name='rides' ORDER BY ordinal_position;",
    'verify-rides'
)

print('\n=== VERIFY: wallet_transactions columns ===')
sql(
    "SELECT column_name FROM information_schema.columns WHERE table_name='wallet_transactions' ORDER BY ordinal_position;",
    'verify-wallet'
)

ssh.close()
print('\nMigration complete.')
