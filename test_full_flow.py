import paramiko, json, sys, urllib.request, urllib.parse
sys.stdout.reconfigure(encoding='utf-8')

BASE = 'http://187.77.116.121'

def api(method, path, body=None, token=None):
    url = BASE + path
    data = json.dumps(body).encode() if body else None
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read())

results = {}

# ─── STEP 0: Health check ──────────────────────────────────────────────────
r = api('GET', '/health')
results['health'] = 'PASS' if r.get('status') == 'ok' else f'FAIL: {r}'
print(f"[HEALTH] {results['health']}")

# ─── STEP 1: Passenger login (085640168132) ────────────────────────────────
print('\n=== PASSENGER LOGIN ===')
otp_r = api('POST', '/auth/send-otp', {'phone': '085640168132'})
otp = otp_r.get('otp', '')
print(f'  send-otp: {otp_r.get("message")} | OTP: {otp}')

verify_r = api('POST', '/auth/verify-otp', {'phone': '085640168132', 'otp': otp})
temp = verify_r.get('tempToken', '')
roles = verify_r.get('availableRoles', [])
print(f'  verify: multipleRoles={verify_r.get("multipleRoles")} roles={roles}')

pass_r = api('POST', '/auth/select-role', {'phone': '085640168132', 'role': 'PASSENGER', 'tempToken': temp})
PTOKEN = pass_r.get('accessToken', '')
PID = pass_r.get('user', {}).get('id', '')
results['passenger_login'] = 'PASS' if PTOKEN else f'FAIL: {pass_r}'
print(f'  select PASSENGER: {results["passenger_login"]} | ID={PID}')

# ─── STEP 2: Passenger get profile ────────────────────────────────────────
print('\n=== PASSENGER PROFILE ===')
prof = api('GET', '/users/profile', token=PTOKEN)
results['passenger_profile'] = 'PASS' if prof.get('id') else f'FAIL: {prof}'
print(f'  GET /users/profile: {results["passenger_profile"]} | name={prof.get("name")}')

# ─── STEP 3: Wallet balance ────────────────────────────────────────────────
print('\n=== WALLET BALANCE ===')
bal = api('GET', '/wallet/balance', token=PTOKEN)
results['wallet_balance'] = 'PASS' if 'balance' in bal else f'FAIL: {bal}'
print(f'  GET /wallet/balance: {results["wallet_balance"]} | balance={bal.get("balance")}')

# ─── STEP 4: Create Ride (Pesan Ojek) ─────────────────────────────────────
print('\n=== CREATE RIDE ===')
ride_r = api('POST', '/booking/rides', {
    'passengerId': PID,
    'originLat': -7.0234, 'originLng': 110.4367,
    'destinationLat': -7.0100, 'destinationLng': 110.4200,
    'originAddress': 'Jl. Pandanaran, Semarang',
    'destinationAddress': 'RSUP Dr. Kariadi, Semarang',
}, token=PTOKEN)
RIDE_ID = ride_r.get('id', '')
results['create_ride'] = 'PASS' if RIDE_ID else f'FAIL: {ride_r}'
print(f'  POST /booking/rides: {results["create_ride"]} | rideId={RIDE_ID} | status={ride_r.get("status")}')

# ─── STEP 5: Driver login ──────────────────────────────────────────────────
print('\n=== DRIVER LOGIN ===')
otp2 = api('POST', '/auth/send-otp', {'phone': '085640168132'})
otp2_code = otp2.get('otp', '')
ver2 = api('POST', '/auth/verify-otp', {'phone': '085640168132', 'otp': otp2_code})
tmp2 = ver2.get('tempToken', '')
drv_r = api('POST', '/auth/select-role', {'phone': '085640168132', 'role': 'DRIVER', 'tempToken': tmp2})
DTOKEN = drv_r.get('accessToken', '')
DID = drv_r.get('user', {}).get('id', '')
results['driver_login'] = 'PASS' if DTOKEN else f'FAIL: {drv_r}'
print(f'  select DRIVER: {results["driver_login"]} | ID={DID}')

# ─── STEP 6: Driver accepts ride ──────────────────────────────────────────
print('\n=== DRIVER ACCEPT RIDE ===')
acc = api('POST', f'/booking/rides/{RIDE_ID}/accept', token=DTOKEN)
results['driver_accept'] = 'PASS' if acc.get('status') == 'ACCEPTED' else f'FAIL: {acc}'
print(f'  POST /booking/rides/{RIDE_ID}/accept: {results["driver_accept"]} | status={acc.get("status")}')

# ─── STEP 7: PICKUP ───────────────────────────────────────────────────────
print('\n=== PICKUP ===')
pu = api('PATCH', f'/booking/rides/{RIDE_ID}/status', {'status': 'PICKUP'}, token=DTOKEN)
results['pickup'] = 'PASS' if pu.get('status') == 'PICKUP' else f'FAIL: {pu}'
print(f'  PATCH status→PICKUP: {results["pickup"]}')

# ─── STEP 8: ONGOING ──────────────────────────────────────────────────────
print('\n=== ONGOING ===')
og = api('PATCH', f'/booking/rides/{RIDE_ID}/status', {'status': 'ONGOING'}, token=DTOKEN)
results['ongoing'] = 'PASS' if og.get('status') == 'ONGOING' else f'FAIL: {og}'
print(f'  PATCH status→ONGOING: {results["ongoing"]}')

# ─── STEP 9: Complete Ride ─────────────────────────────────────────────────
print('\n=== COMPLETE RIDE ===')
done = api('POST', f'/booking/rides/{RIDE_ID}/complete', token=DTOKEN)
fare = done.get('fare', 0)
results['complete_ride'] = 'PASS' if done.get('ride', {}).get('status') == 'DONE' else f'FAIL: {done}'
print(f'  POST .../complete: {results["complete_ride"]} | fare=Rp {fare:,.0f}')

# ─── STEP 10: Passenger rate driver ───────────────────────────────────────
print('\n=== RATE DRIVER ===')
rate = api('POST', f'/booking/rides/{RIDE_ID}/rate', {'rating': 5}, token=PTOKEN)
results['rate'] = 'PASS' if 'message' in rate else f'FAIL: {rate}'
print(f'  POST .../rate: {results["rate"]} | msg={rate.get("message")}')

# ─── STEP 11: Driver wallet credit ────────────────────────────────────────
print('\n=== DRIVER WALLET ===')
drv_bal = api('GET', '/wallet/balance', token=DTOKEN)
results['driver_wallet'] = 'PASS' if 'balance' in drv_bal else f'FAIL: {drv_bal}'
print(f'  Driver balance after trip: {results["driver_wallet"]} | Rp {drv_bal.get("balance", 0):,.0f}')

# ─── STEP 12: History ─────────────────────────────────────────────────────
print('\n=== PASSENGER HISTORY ===')
hist = api('GET', '/users/history', token=PTOKEN)
results['history'] = 'PASS' if isinstance(hist, list) else f'FAIL: {hist}'
print(f'  GET /users/history: {results["history"]} | count={len(hist) if isinstance(hist, list) else "?"}')

# ─── STEP 13: Admin login & stats ─────────────────────────────────────────
print('\n=== ADMIN ===')
otp3 = api('POST', '/auth/send-otp', {'phone': '085640168132'})
otp3_code = otp3.get('otp', '')
ver3 = api('POST', '/auth/verify-otp', {'phone': '085640168132', 'otp': otp3_code})
tmp3 = ver3.get('tempToken', '')
adm = api('POST', '/auth/select-role', {'phone': '085640168132', 'role': 'ADMIN', 'tempToken': tmp3})
ATOKEN = adm.get('accessToken', '')
results['admin_login'] = 'PASS' if ATOKEN else f'FAIL: {adm}'
print(f'  Admin login: {results["admin_login"]}')

stats = api('GET', '/admin/stats', token=ATOKEN)
results['admin_stats'] = 'PASS' if 'totalUsers' in stats else f'FAIL: {stats}'
print(f'  GET /admin/stats: {results["admin_stats"]} | trips={stats.get("activeTrips")} users={stats.get("totalUsers")}')

users_a = api('GET', '/admin/users?page=1&limit=5', token=ATOKEN)
results['admin_users'] = 'PASS' if isinstance(users_a.get('users', users_a), list) else f'FAIL: {users_a}'
print(f'  GET /admin/users: {results["admin_users"]}')

trips_a = api('GET', '/admin/trips?page=1&limit=5', token=ATOKEN)
results['admin_trips'] = 'PASS' if isinstance(trips_a.get('trips', trips_a), list) else f'FAIL: {trips_a}'
print(f'  GET /admin/trips: {results["admin_trips"]}')

drivers_a = api('GET', '/admin/drivers', token=ATOKEN)
results['admin_drivers'] = 'PASS' if isinstance(drivers_a, list) else f'FAIL: {drivers_a}'
print(f'  GET /admin/drivers: {results["admin_drivers"]}')

tariff_a = api('GET', '/admin/tariff', token=ATOKEN)
results['admin_tariff'] = 'PASS' if 'basePrice' in tariff_a else f'FAIL: {tariff_a}'
print(f'  GET /admin/tariff: {results["admin_tariff"]}')

complaints_a = api('GET', '/admin/complaints', token=ATOKEN)
results['admin_complaints'] = 'PASS' if isinstance(complaints_a.get('complaints', complaints_a), list) else f'FAIL: {complaints_a}'
print(f'  GET /admin/complaints: {results["admin_complaints"]}')

# ─── STEP 14: Chat test (REST) ────────────────────────────────────────────
print('\n=== CHAT REST ===')
chat_h = api('GET', f'/chat/{RIDE_ID}/history', token=PTOKEN)
results['chat_history'] = 'PASS' if isinstance(chat_h, list) else f'FAIL: {chat_h}'
print(f'  GET /chat/{RIDE_ID}/history: {results["chat_history"]}')

# ─── SUMMARY ──────────────────────────────────────────────────────────────
print('\n' + '='*60)
print('TEST SUMMARY')
print('='*60)
passed = sum(1 for v in results.values() if v == 'PASS')
total  = len(results)
for k, v in results.items():
    icon = '✓' if v == 'PASS' else '✗'
    print(f'  {icon} {k:<25} {v}')
print(f'\nTOTAL: {passed}/{total} PASS')
print(f'\nKEY IDs:')
print(f'  PASSENGER_ID: {PID}')
print(f'  DRIVER_ID: {DID}')
print(f'  RIDE_ID: {RIDE_ID}')
print(f'  FARE: Rp {fare:,.0f}')
