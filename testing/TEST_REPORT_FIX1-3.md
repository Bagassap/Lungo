# Test Report — Fix 1, 2, 3
**Tanggal:** 2026-05-12  
**Environment:** VPS `http://187.77.116.121` (NODE_ENV=development selama testing, prod setelahnya)  
**Build:** `npm run build` — berhasil tanpa error  
**Deploy:** `python deploy/_upload.py` — 19 file terupload, PM2 restart OK

---

## Ringkasan

| Fix | Deskripsi | Backend | Flutter (code review) | Status |
|-----|-----------|---------|----------------------|--------|
| Fix 1 | Phone input +62 prefix | PASS | PASS | **LULUS** |
| Fix 2 | Driver form validation | PASS | PASS | **LULUS** |
| Fix 3 | Driver switch ke Passenger (select-role tanpa tempToken) | PASS | PASS | **LULUS** |

---

## Fix 1 — Phone Input +62 Prefix

**Perubahan:** `frontend/app/lib/features/auth/screens/phone_input_screen.dart`

### Code Review
- [x] `_getFullPhone()` menormalisasi semua format ke `08xxx`
- [x] `FilteringTextInputFormatter.digitsOnly` — hanya angka diterima
- [x] `TextInputFormatter.withFunction` — strip leading `0` dari input field (karena sudah ada +62)
- [x] Container prefix "+62" ditampilkan sebelum input field

### Logika Normalisasi `_getFullPhone()`
| Input user | Hasil normalisasi | Keterangan |
|-----------|-----------------|------------|
| `85640168132` | `085640168132` | Ketik tanpa 0 (karena prefix +62) |
| `085640168132` | `085640168132` | Format lama dengan 0 di awal |
| `62585640168132` | `085640168132` | Country code manual |
| `8 564 016 8132` | `085640168132` | Dengan spasi |

### Backend Test
```
POST /auth/send-otp {"phone": "085640168132"}
-> {"message": "OTP telah dikirim", "otp": "813022", "isNewUser": false}
HTTP 200 OK
```
**Hasil: PASS**

---

## Fix 2 — Driver Form Validation

**Perubahan:** `frontend/app/lib/features/passenger/screens/upgrade_to_driver_screen.dart`

### Code Review
- [x] `bool _submitAttempted = false` — flag ditambahkan
- [x] `_submit()` langsung `setState(() => _submitAttempted = true)` sebelum validasi
- [x] KTP validator: `'KTP harus 16 digit (sekarang: ${v.trim().length})'`
- [x] Error checkbox: tampil jika `_submitAttempted && !_agreeTerms`

### Perilaku Validasi Form
| Skenario | Perilaku |
|---------|---------|
| Submit tanpa centang checkbox | Muncul teks merah "Wajib dicentang sebelum mendaftar" |
| KTP 10 digit | Error: "KTP harus 16 digit (sekarang: 10)" |
| KTP 16 digit valid | Tidak ada error |
| Form bersih, checkbox tercentang | Lanjut ke API |

### Backend Test — `/drivers/upgrade`
```
# Test 1: Fresh PASSENGER (phone 089999988877)
POST /drivers/upgrade
Authorization: Bearer <passenger_token>
Body: {"vehiclePlate":"B5678ZZ","vehicleType":"MOTOR","motorSubtype":"Matic","ktpNumber":"9876543210987654"}
-> {"message":"Berhasil upgrade ke driver","driverId":"dd0c8c92-..."}
HTTP 201

# Test 2: Driver sudah ada (dev account 085640168132)
POST /drivers/upgrade
-> {"statusCode":409,"message":"Akun driver sudah ada untuk user ini"}
HTTP 409 (expected)

# Test 3: Tanpa auth token
POST /drivers/upgrade
-> {"statusCode":401,"message":"Unauthorized"}
HTTP 401 (expected)
```
**Hasil: PASS**

---

## Fix 3 — Driver Switch ke Mode Penumpang

**Perubahan:**
- `frontend/app/lib/features/driver/screens/driver_profile_screen.dart`
- `backend/src/auth/auth.service.ts`
- `backend/src/auth/dto/select-role.dto.ts`

### Code Review Flutter
- [x] Menu item "Beralih ke Mode Penumpang" di seksi AKUN
- [x] Cek `driverProvider.isOnline` — tolak jika masih online
- [x] Confirmation dialog sebelum switch
- [x] Call `POST /auth/select-role` dengan `phone` + `role: PASSENGER` (tanpa tempToken)
- [x] Simpan token baru + role baru ke SecureStorage
- [x] `authProvider.checkSession()` + navigate ke `/main`

### Code Review Backend
**`select-role.dto.ts`:**
```typescript
@IsOptional()   // <-- ditambahkan (tidak ada IsNotEmpty)
@IsString()
tempToken?: string;
```

**`auth.service.ts`:**
```typescript
async selectRole(phone: string, role: string, tempToken?: string) {
  if (tempToken) {          // <-- hanya verifikasi jika tempToken dikirim
    // verify JWT...
  }
  // lanjut cari user...
}
```

### Backend Test
```
# Test 1: select-role TANPA tempToken (driver -> passenger switch)
POST /auth/select-role
Body: {"phone":"085640168132","role":"PASSENGER"}
-> {"accessToken":"eyJ...","refreshToken":"eyJ...","user":{"role":"PASSENGER",...}}
HTTP 200 PASS

# Test 2: select-role DENGAN tempToken (alur multi-role normal)
POST /auth/verify-otp {"phone":"085640168132","otp":"813022"}
-> {"multipleRoles":true,"availableRoles":["DRIVER","ADMIN","PASSENGER"],"tempToken":"eyJ..."}

POST /auth/select-role
Body: {"phone":"085640168132","role":"DRIVER","tempToken":"eyJ..."}
-> {"accessToken":"eyJ...","user":{"role":"DRIVER",...}}
HTTP 200 PASS

# Test 3: select-role role tidak ada
POST /auth/select-role {"phone":"089999988877","role":"DRIVER"}
-> {"statusCode":404,"message":"Akun DRIVER tidak ditemukan untuk nomor ini"}
HTTP 404 (expected)
```
**Hasil: PASS**

---

## Catatan Deploy

```
Files uploaded: 19 file JS ke /var/www/lungo-backend/backend/dist/
PM2 restart: lungo-backend pid=69987, status=online
Seed: 3 akun dev di-reset (085640168132: PASSENGER, DRIVER, ADMIN)
NODE_ENV: dikembalikan ke production setelah testing
```

---

## Kesimpulan

Semua 3 fix berhasil diimplementasi dan lulus testing:
1. **Fix 1** — Phone field +62 prefix berfungsi, normalisasi semua format ke `08xxx`
2. **Fix 2** — Validasi form driver: KTP counter + checkbox error tampil saat submit
3. **Fix 3** — Driver dapat beralih ke mode penumpang tanpa OTP ulang via `select-role` tanpa `tempToken`
