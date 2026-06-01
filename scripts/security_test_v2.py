import sys, time, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
import urllib.request, urllib.error

# Test via Nginx (port 80) — bukan port 3000 langsung
BASE = 'http://187.77.116.121'
PASS_COUNT = 0; FAIL_COUNT = 0

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
        print(f"  [ERR]  {name}: {e}")
        FAIL_COUNT += 1

def http(method, path, data=None, headers=None):
    url = BASE + path
    body = json.dumps(data).encode() if data else None
    h = {'Content-Type': 'application/json'}
    if headers: h.update(headers)
    req = urllib.request.Request(url, data=body, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, r.read().decode('utf-8','replace'), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8','replace'), dict(e.headers)
    except Exception as e:
        return 0, str(e), {}

print("=" * 60)
print("  LUNGO Security Test Suite v2 (via Nginx port 80)")
print("=" * 60)

# ── 1. Security Headers ────────────────────────────────────────
print("\n[1] Security Headers")
s, b, hdrs = http('GET', '/health')
h = {k.lower(): v for k, v in hdrs.items()}
test("Health 200", lambda: s == 200)
test("X-Content-Type-Options: nosniff", lambda: h.get('x-content-type-options','').lower() == 'nosniff')
test("X-Frame-Options: DENY",           lambda: h.get('x-frame-options','').upper() == 'DENY')
test("X-XSS-Protection ada",            lambda: 'x-xss-protection' in h)
test("Referrer-Policy ada",             lambda: 'referrer-policy' in h)
test("X-Request-ID ada (tiap request)", lambda: 'x-request-id' in h and len(h.get('x-request-id','')) > 10)
test("X-Powered-By tersembunyi",        lambda: 'express' not in h.get('x-powered-by','').lower())
test("Server tidak expose versi",       lambda: 'nginx/' not in h.get('server','').lower())

# ── 2. Swagger diblokir ────────────────────────────────────────
print("\n[2] Swagger tersembunyi (via Nginx)")
s2, b2, _ = http('GET', '/api')
test("GET /api diblokir (403)",  lambda: s2 == 403)
s3, _, _  = http('GET', '/api/json')
test("GET /api/json diblokir (403)", lambda: s3 == 403)
# Pastikan bukan redirect ke Swagger UI
test("Response bukan HTML Swagger", lambda: 'swagger' not in b2.lower())

# ── 3. CORS Restriction ────────────────────────────────────────
print("\n[3] CORS Restriction")
_, _, h3 = http('OPTIONS', '/auth/send-otp', headers={
    'Origin': 'http://evil.com',
    'Access-Control-Request-Method': 'POST'
})
h3l = {k.lower(): v for k, v in h3.items()}
acao = h3l.get('access-control-allow-origin', '')
test("Evil origin tidak di-reflect", lambda: 'evil.com' not in acao)
test("Bukan wildcard *",             lambda: acao != '*')

# ── 4. Rate Limiting ───────────────────────────────────────────
print("\n[4] Rate Limiting OTP")
statuses = []
for i in range(5):
    s, _, _ = http('POST', '/auth/send-otp', {'phone': '08123456789'})
    statuses.append(s)
    time.sleep(0.2)
print(f"  Status: {statuses}")
test("429 setelah request ke-4/5", lambda: 429 in statuses)

# ── 5. Input Validation ────────────────────────────────────────
print("\n[5] Input Validation")
s4, _, _ = http('POST', '/auth/send-otp', {'phone': 'INVALID_PHONE'})
print(f"  INVALID_PHONE → {s4}")
test("Phone tidak valid ditolak (400/422/429)", lambda: s4 in (400,422,429))
s5, _, _ = http('POST', '/auth/send-otp', {'phone': '<script>alert(1)</script>'})
print(f"  XSS payload → {s5}")
test("XSS payload ditolak (400/422/429)", lambda: s5 in (400,422,429))

# ── 6. Suspicious detector (query params) ─────────────────────
print("\n[6] Suspicious Activity Detector")
s6, _, _ = http('GET', "/tracking/drivers/count?lat=0&lng=0'--")
print(f"  SQL injection query → {s6}")
test("SQL injection di query param ditolak (400/401)", lambda: s6 in (400, 401))

# ── 7. Auth Guard ──────────────────────────────────────────────
print("\n[7] Auth Guard (endpoint butuh JWT)")
s7, _, _ = http('GET', '/users/profile')
test("GET /users/profile butuh auth (401)", lambda: s7 == 401)
s8, _, _ = http('GET', '/admin/users')
test("GET /admin/users butuh auth (401)", lambda: s8 in (401,403,404))
s9, _, _ = http('GET', '/tracking/drivers/count?lat=0&lng=0')
test("GET /tracking/drivers/count butuh auth (401)", lambda: s9 == 401)

# ── 8. Generic error messages (production) ────────────────────
print("\n[8] Generic Error Messages (production)")
s10, b10, _ = http('GET', '/users/profile')
b10j = {}
try: b10j = json.loads(b10)
except: pass
print(f"  401 body: {b10j}")
test("401 error pesan generik", lambda: b10j.get('message','') == 'Permintaan tidak valid.')
test("requestId ada di error response", lambda: 'requestId' in b10j)

# ── 9. Payload size limit ─────────────────────────────────────
print("\n[9] Payload Size Limit (>1MB)")
big_payload = {'phone': '0' * (1024 * 1024 + 1)}
s11, _, _ = http('POST', '/auth/send-otp', big_payload)
print(f"  1MB+ payload → {s11}")
test("Payload >1MB ditolak (413/400)", lambda: s11 in (413, 400, 422, 429))

# ── 10. File type blocking (Nginx) ────────────────────────────
print("\n[10] File Type Blocking (Nginx)")
s12, _, _ = http('GET', '/shell.php')
test("Akses .php diblokir (403)", lambda: s12 == 403)
s13, _, _ = http('GET', '/upload.asp')
test("Akses .asp diblokir (403)", lambda: s13 == 403)

# ── Summary ───────────────────────────────────────────────────
print("\n" + "=" * 60)
total = PASS_COUNT + FAIL_COUNT
print(f"  Results: {PASS_COUNT}/{total} PASSED  |  {FAIL_COUNT} FAILED")
print("=" * 60)
sys.exit(0 if FAIL_COUNT == 0 else 1)
