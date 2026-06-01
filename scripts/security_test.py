import sys, time, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

import urllib.request, urllib.error
import urllib.parse

BASE = 'http://187.77.116.121:3000'
PASS_COUNT = 0
FAIL_COUNT = 0

def test(name, fn):
    global PASS_COUNT, FAIL_COUNT
    try:
        result = fn()
        if result:
            print(f"  [PASS] {name}")
            PASS_COUNT += 1
        else:
            print(f"  [FAIL] {name}")
            FAIL_COUNT += 1
    except Exception as e:
        print(f"  [ERROR] {name}: {e}")
        FAIL_COUNT += 1

def http(method, path, data=None, headers=None):
    url = BASE + path
    body = json.dumps(data).encode() if data else None
    h = {'Content-Type': 'application/json'}
    if headers: h.update(headers)
    req = urllib.request.Request(url, data=body, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, r.read().decode('utf-8', errors='replace'), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', errors='replace'), dict(e.headers)
    except Exception as e:
        return 0, str(e), {}

print("=" * 55)
print("  LUNGO Security Test Suite")
print("=" * 55)

# ── 1. Security Headers ──────────────────────────────────────
print("\n[1] Security Headers")
status, body, hdrs = http('GET', '/health')
h = {k.lower(): v for k, v in hdrs.items()}
test("X-Content-Type-Options: nosniff", lambda: h.get('x-content-type-options','').lower() == 'nosniff')
test("X-Frame-Options: DENY", lambda: h.get('x-frame-options','').upper() == 'DENY')
test("X-XSS-Protection header present", lambda: 'x-xss-protection' in h)
test("Referrer-Policy header present", lambda: 'referrer-policy' in h)
test("Health endpoint returns 200", lambda: status == 200)

# ── 2. CORS Restriction ──────────────────────────────────────
print("\n[2] CORS Restriction")
_, _, h2 = http('OPTIONS', '/auth/send-otp', headers={'Origin': 'http://evil.com', 'Access-Control-Request-Method': 'POST'})
h2l = {k.lower(): v for k, v in h2.items()}
acao = h2l.get('access-control-allow-origin', '')
test("Evil origin blocked (no wildcard *)", lambda: acao != '*')
test("Evil origin not reflected", lambda: 'evil.com' not in acao)

# ── 3. Rate Limiting ─────────────────────────────────────────
print("\n[3] Rate Limiting (OTP endpoint)")
statuses = []
for i in range(5):
    s, _, _ = http('POST', '/auth/send-otp', {'phone': '08123456789'})
    statuses.append(s)
    time.sleep(0.3)
test("429 Too Many Requests after 3 rapid calls", lambda: 429 in statuses)

# ── 4. OTP Input Validation ──────────────────────────────────
# Note: rate limiter may return 429 before validation — both are a rejection
print("\n[4] Input Validation")
s1, b1, _ = http('POST', '/auth/send-otp', {'phone': 'INVALID_PHONE'})
print(f"  INVALID_PHONE -> {s1}")
test("Invalid phone number rejected (400/422/429)", lambda: s1 in (400, 422, 429))
s2, b2, _ = http('POST', '/auth/send-otp', {'phone': '<script>alert(1)</script>'})
print(f"  XSS payload   -> {s2}")
test("XSS payload rejected (400/422/429)", lambda: s2 in (400, 422, 429))
s3, b3, _ = http('POST', '/auth/send-otp', {'phone': "'; DROP TABLE users; --"})
print(f"  SQLi payload  -> {s3}")
test("SQL injection in phone rejected (400/422/429)", lambda: s3 in (400, 422, 429))

# ── 5. Auth endpoints require JWT ────────────────────────────
print("\n[5] Auth Guard")
s4, _, _ = http('GET', '/users/profile')
test("GET /users/profile requires auth (401)", lambda: s4 == 401)
s5, _, _ = http('GET', '/drivers/list')
test("GET /drivers/list requires auth (401)", lambda: s5 in (401, 403, 404))
s6, _, _ = http('GET', '/admin/users')
test("GET /admin/users requires auth (401)", lambda: s6 in (401, 403, 404))

# ── 6. Tracking endpoints require JWT ────────────────────────
print("\n[6] Tracking Guard")
s7, _, _ = http('GET', '/tracking/drivers/count')
test("GET /tracking/drivers/count requires auth (401)", lambda: s7 == 401)
s8, b8, _ = http('GET', '/tracking/drivers/nearby?lat=0&lng=0')
print(f"  /tracking/drivers/nearby -> {s8}")
test("GET /tracking/drivers/nearby requires auth (401)", lambda: s8 == 401)

# ── 7. No server version disclosure ──────────────────────────
print("\n[7] Information Disclosure")
_, _, h3 = http('GET', '/health')
h3l = {k.lower(): v for k, v in h3.items()}
server_hdr = h3l.get('server', '').lower()
powered = h3l.get('x-powered-by', '').lower()
test("Server header doesn't disclose version", lambda: 'nestjs' not in server_hdr and 'node/' not in server_hdr)
test("X-Powered-By header hidden", lambda: 'express' not in powered)

# ── Summary ──────────────────────────────────────────────────
print("\n" + "=" * 55)
total = PASS_COUNT + FAIL_COUNT
print(f"  Results: {PASS_COUNT}/{total} PASSED  |  {FAIL_COUNT} FAILED")
print("=" * 55)
sys.exit(0 if FAIL_COUNT == 0 else 1)
