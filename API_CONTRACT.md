# API_CONTRACT — VisionGuard REST API v1 (Tahap A + B)

Kontrak JSON antara aplikasi Flutter dan backend Laravel (`./backend`).
Menutup DOCS_SPEC §16 #8 dan #9. Bila bertentangan dengan `DOCS_SPEC.md`, `DOCS_SPEC.md` yang berlaku.

- **Base URL:** `http(s)://<host>/api` (lokal: `http://127.0.0.1:8000/api`). Produksi wajib HTTPS (KMN-01).
- **Format:** request & respons `application/json`. Semua rute `/api` selalu menjawab JSON, walau header `Accept` tidak dikirim.
- **Auth:** header `Authorization: Bearer <token>` (Laravel Sanctum), kecuali rute bertanda *publik*.
- **Tanggal:** `day` = `YYYY-MM-DD` menurut `users.timezone`; waktu (`*_at`) = ISO 8601 UTC, mis. `2026-11-16T03:00:00+00:00`.
- **Respons datar** (tanpa pembungkus `data`).

## Format error

| Kode | Arti | Body |
|---|---|---|
| 401 | Token tidak ada/tidak berlaku, atau kredensial login salah | `{ "message": "Unauthenticated." }` / `{ "message": "Email atau kata sandi salah." }` |
| 402 | Kuota gratis & kredit habis (aktivasi) | `{ "message": "...", ...status kredit }` |
| 403 | Verifikasi kata sandi gagal (hapus akun) / signature notifikasi salah | `{ "message": "..." }` |
| 404 | Rute/order tidak ada, email tidak terdaftar (lupa sandi) | `{ "message": "..." }` |
| 422 | Validasi gagal | `{ "message": "...", "errors": { "field": ["pesan", ...] } }` |
| 429 | Login ditahan / batas Saran AI / lupa sandi terlalu sering | `{ "message": "...", "retry_after": 300 }` + header `Retry-After` |
| 503 | Layanan AI / gerbang pembayaran tidak tersedia | `{ "message": "..." }` |

## Ringkasan endpoint

| Method | Path | Auth | Sukses | Error |
|---|---|---|---|---|
| POST | `/auth/register` | publik | 201 | 422 |
| POST | `/auth/login` | publik | 200 | 401, 422, 429 |
| POST | `/auth/forgot-password` | publik | 200 | 404, 422, 429 |
| POST | `/auth/reset-password` | publik | 200 | 422, 429 |
| POST | `/auth/logout` | token | 200 | 401 |
| GET | `/me` | token | 200 | 401 |
| DELETE | `/me` | token | 200 | 401, 403, 422 |
| POST | `/monitoring-days/activate` | token | 200 | 401, 402, 422 |
| GET | `/credits/status` | token | 200 | 401 |
| GET | `/credit-packages` | token | 200 | 401 |
| GET | `/credits/history` | token | 200 | 401 |
| POST | `/orders` | token | 201 | 401, 422, 503 |
| GET | `/orders/{order_code}` | token | 200 | 401, 404 |
| POST | `/payments/midtrans/notification` | publik (signature) | 200 | 403, 404, 422 |
| POST | `/stats/daily` | token | 200 | 401, 422 |
| GET | `/stats?range=7\|30` | token | 200 | 401, 422 |
| POST | `/ai/advice` | token | 200 | 401, 422, 429, 503 |

Halaman web (di luar `/api`): `/payments/finish`, `/payments/unfinish`, `/payments/error`, `/payments/simulate/{order_code}` (mode simulasi), `/reset-password/{token}`. Panel admin: `/admin` (Filament, role admin).

---

## Akun

### POST /auth/register — UC-01 *(publik)*

Request:
```json
{
  "name": "Budi",
  "email": "budi@contoh.id",
  "password": "rahasia123",
  "timezone": "Asia/Jakarta",
  "platform": "android",
  "device_name": "Pixel 7"
}
```
- `name` wajib, ≤ 100 · `email` wajib, format email, ≤ 150, unik (huruf kecil otomatis) · `password` wajib, 8–72 karakter.
- `timezone` opsional (zona IANA; bawaan `Asia/Jakarta`).
- `platform` wajib: `windows | macos | android | ios` · `device_name` wajib, ≤ 100. Perangkat dicatat di `devices`.

**201 Created**
```json
{
  "token": "1|f3Kq...",
  "token_type": "Bearer",
  "device_id": 7,
  "user": {
    "id": 12,
    "name": "Budi",
    "email": "budi@contoh.id",
    "role": "user",
    "timezone": "Asia/Jakarta",
    "created_at": "2026-11-16T03:00:00+00:00"
  }
}
```
**422** email sudah dipakai:
```json
{
  "message": "Email sudah terdaftar. Silakan login atau reset kata sandi.",
  "errors": { "email": ["Email sudah terdaftar. Silakan login atau reset kata sandi."] }
}
```

### POST /auth/login — UC-02 *(publik)*

Request:
```json
{ "email": "demo@visionguard.id", "password": "password123", "platform": "windows", "device_name": "Laptop Budi" }
```
**200 OK** — sama dengan respons register (`token`, `token_type`, `device_id`, `user`).
Perangkat dengan `platform` + `device_name` yang sama dipakai ulang dan `last_seen_at` diperbarui.
Klien menyimpan `device_id` untuk `POST /monitoring-days/activate` dan `POST /stats/daily`.

**401**
```json
{ "message": "Email atau kata sandi salah." }
```
**429** setelah 5 kali gagal berturut-turut (per email + IP), ditahan 5 menit. Login sukses mereset hitungan.
```json
{ "message": "Terlalu banyak percobaan login. Coba lagi dalam 5 menit.", "retry_after": 300 }
```

### POST /auth/forgot-password — UC-03 *(publik)*

Request:
```json
{ "email": "budi@contoh.id" }
```
**200 OK** — email berisi tautan `https://<host>/reset-password/<token>?email=...` (berlaku 60 menit).
```json
{ "message": "Tautan reset kata sandi telah dikirim ke email Anda. Berlaku 60 menit." }
```
**404** `{ "message": "Email tidak terdaftar." }` · **429** diminta lagi < 60 detik untuk email yang sama, atau > 10 request/menit/IP.

Pengguna mengisi sandi baru di halaman web tersebut. Klien juga boleh memanggil endpoint berikut langsung.

### POST /auth/reset-password — UC-03 *(publik)*

Request (sandi diisi dua kali):
```json
{ "email": "budi@contoh.id", "token": "<token dari tautan>", "password": "sandiBaru123", "password_confirmation": "sandiBaru123" }
```
**200 OK** — semua token Sanctum pengguna dicabut; login ulang dengan sandi baru.
```json
{ "message": "Kata sandi berhasil diganti. Silakan login." }
```
**422** token salah/kedaluwarsa/sudah dipakai:
```json
{
  "message": "Tautan reset tidak valid atau sudah kedaluwarsa. Minta tautan baru.",
  "errors": { "token": ["Tautan reset tidak valid atau sudah kedaluwarsa. Minta tautan baru."] }
}
```
**422** juga untuk `password` < 8 karakter atau konfirmasi tidak sama (`errors.password`).

### POST /auth/logout — UC-04

Mencabut token yang dipakai request ini (perangkat ini saja). Body kosong.

**200 OK**
```json
{ "message": "Berhasil keluar." }
```

### GET /me

**200 OK**
```json
{ "user": { "id": 12, "name": "Budi", "email": "budi@contoh.id", "role": "user", "timezone": "Asia/Jakarta", "created_at": "2026-11-16T03:00:00+00:00" } }
```

### DELETE /me — UC-05

Request:
```json
{ "password": "rahasia123" }
```
**200 OK**
```json
{ "message": "Akun dan data pribadi telah dihapus." }
```
Dihapus: akun, `devices`, `daily_stats`, semua token. Dianonimkan (`user_id = NULL`): `orders`, `credit_ledger`, `monitoring_days`. Sisa kredit hilang.
Klien lalu menghapus data lokal (kalibrasi, metrik, pengaturan, token) dan kembali ke login.

**403**
```json
{ "message": "Kata sandi salah. Akun tidak dihapus." }
```
**422** bila `password` tidak dikirim.

---

## Kredit & Hari Pemantauan

### Objek status kredit

Dipakai oleh `GET /credits/status` dan disisipkan di respons aktivasi (200 & 402).
```json
{
  "today": "2026-11-16",
  "timezone": "Asia/Jakarta",
  "today_active": true,
  "today_source": "free",
  "free_quota_remaining": 1,
  "free_quota_per_month": 2,
  "credit_balance": 4,
  "updated_at": "2026-11-16T03:00:00+00:00"
}
```
- `today_source`: `free | credit | null`.
- `credit_balance` = SUM(`credit_ledger.delta`), selalu dihitung server (KMN-03).
- `updated_at`: waktu server saat respons dibuat (untuk tampilan offline UC-18).

### POST /monitoring-days/activate — PMT-01, §8.2

Request (`device_id` opsional, harus milik pengguna):
```json
{ "device_id": 7 }
```
**200 OK** — hari diaktifkan, atau sudah aktif sebelumnya (`already_active: true`, tidak memotong apa pun):
```json
{
  "message": "Hari Pemantauan AI diaktifkan.",
  "source": "credit",
  "already_active": false,
  "today": "2026-11-16",
  "timezone": "Asia/Jakarta",
  "today_active": true,
  "today_source": "credit",
  "free_quota_remaining": 0,
  "free_quota_per_month": 2,
  "credit_balance": 3,
  "updated_at": "2026-11-16T03:00:00+00:00"
}
```
**402 Payment Required** — kuota gratis bulan ini habis dan saldo < 1. Klien menawarkan beli kredit atau Mode Timer.
```json
{
  "message": "Kredit tidak cukup. Beli kredit atau gunakan Mode Timer.",
  "today": "2026-11-16",
  "timezone": "Asia/Jakarta",
  "today_active": false,
  "today_source": null,
  "free_quota_remaining": 0,
  "free_quota_per_month": 2,
  "credit_balance": 0,
  "updated_at": "2026-11-16T03:00:00+00:00"
}
```
**422** bila `device_id` bukan milik pengguna.

### GET /credits/status — KRD-01, UC-18

**200 OK** — objek status kredit (di atas).

### GET /credit-packages — UC-19

Hanya paket `is_active = true`, urut harga.

**200 OK**
```json
{
  "packages": [
    { "id": 1, "name": "Paket Hemat", "credits": 5, "price_idr": 15000, "is_active": true },
    { "id": 2, "name": "Paket Reguler", "credits": 12, "price_idr": 30000, "is_active": true }
  ]
}
```

### GET /credits/history — KRD-04, UC-20

Order dan mutasi ledger, masing-masing terbaru dulu.

**200 OK**
```json
{
  "credit_balance": 4,
  "orders": [
    {
      "id": 3,
      "order_code": "VG-20261116-AB12CD",
      "package_id": 1,
      "package_name": "Paket Hemat",
      "credits": 5,
      "amount_idr": 15000,
      "status": "settlement",
      "payment_type": "qris",
      "paid_at": "2026-11-16T02:10:00+00:00",
      "created_at": "2026-11-16T02:05:00+00:00"
    }
  ],
  "ledger": [
    { "id": 9, "delta": -1, "reason": "usage", "order_id": null, "monitoring_day_id": 21, "day": "2026-11-16", "note": null, "created_at": "2026-11-16T03:00:00+00:00" },
    { "id": 8, "delta": 5, "reason": "purchase", "order_id": 3, "monitoring_day_id": null, "day": null, "note": null, "created_at": "2026-11-16T02:10:00+00:00" }
  ]
}
```
- `orders[].status`: `pending | settlement | expire | cancel | deny`.
- `ledger[].reason`: `purchase | usage | adjustment` (`note` terisi untuk `adjustment`).

---

## Pembayaran (§8.4, UC-19)

Mode server (`PAYMENT_MODE`): `midtrans` (Snap Sandbox/Production) atau `simulation` (halaman bayar tiruan; otomatis dipakai bila server key kosong, ditolak di produksi). Klien memperlakukan keduanya sama: buka `redirect_url`, lalu muat ulang status.

### POST /orders

Request:
```json
{ "package_id": 1 }
```
**201 Created** — order `pending`, harga dari server.
```json
{
  "order_code": "VG-261116100500-AB12CD",
  "snap_token": "66e4fa55-fdac-4ef9-91b5-733b97d1b862",
  "redirect_url": "https://app.sandbox.midtrans.com/snap/v4/redirection/66e4fa55-fdac-4ef9-91b5-733b97d1b862",
  "payment_mode": "midtrans",
  "order": {
    "id": 3,
    "order_code": "VG-261116100500-AB12CD",
    "package_id": 1,
    "package_name": "Paket Hemat",
    "credits": 5,
    "amount_idr": 15000,
    "status": "pending",
    "payment_type": null,
    "paid_at": null,
    "created_at": "2026-11-16T03:05:00+00:00"
  }
}
```
- Mode `simulation`: `snap_token` berawalan `SIM-`, `redirect_url` = `https://<host>/payments/simulate/<order_code>`.
- Setelah bayar, Snap mengarahkan ke `/payments/finish?order_id=...` yang meminta pengguna kembali ke aplikasi.

**422** paket tidak ada/nonaktif: `{ "message": "Paket kredit tidak tersedia.", "errors": { "package_id": ["Paket kredit tidak tersedia."] } }`
**503** Midtrans gagal (order tidak dibuat): `{ "message": "Gagal membuat transaksi pembayaran." }`

### GET /orders/{order_code}

Untuk tombol "Muat ulang status". Hanya order milik pengguna (lainnya **404**).
Bila order masih `pending` dan mode `midtrans`, server mengecek Status API Midtrans dan memprosesnya seperti notifikasi (idempoten).

**200 OK**
```json
{ "order": { "order_code": "VG-261116100500-AB12CD", "status": "settlement", "payment_type": "qris", "paid_at": "2026-11-16T03:10:00+00:00", "...": "..." }, "credit_balance": 9 }
```

### POST /payments/midtrans/notification *(publik, dipanggil Midtrans)*

Isi **Payment Notification URL** di dashboard Midtrans: `https://<host>/api/payments/midtrans/notification`. Tanpa token, tanpa CSRF.

Request (contoh dari Midtrans):
```json
{
  "order_id": "VG-261116100500-AB12CD",
  "status_code": "200",
  "gross_amount": "15000.00",
  "transaction_status": "settlement",
  "fraud_status": "accept",
  "payment_type": "qris",
  "settlement_time": "2026-11-16 10:10:00",
  "signature_key": "<sha512>"
}
```
- `signature_key` wajib = `SHA512(order_id + status_code + gross_amount + SIGNATURE_SECRET_KEY)` (model access key baru Midtrans).
  Bila `MIDTRANS_SIGNATURE_SECRET_KEY` server kosong, dipakai Server Key (format lama) dan server mencatat peringatan.
  Kunci yang sama memverifikasi respons Status API pada `GET /orders/{order_code}`.

| Kondisi | Hasil | HTTP |
|---|---|---|
| Signature tidak valid / field kurang | ditolak, dicatat di log | 403 |
| `order_id` tidak dikenal | dicatat di log | 404 |
| `gross_amount` ≠ harga order | ditolak, dicatat di log | 422 |
| `settlement`, atau `capture` + `fraud_status=accept` | order `settlement` (+`payment_type`, `paid_at`) + ledger `purchase` (+kredit paket), sekali saja | 200 |
| `pending`, `capture` + `challenge` | tidak berubah | 200 |
| `expire` / `cancel` / `deny` / `failure` | order `expire` / `cancel` / `deny` / `deny`, tanpa kredit (hanya bila masih pending) | 200 |
| Notifikasi berulang | tidak menambah kredit lagi | 200 |

Respons: `{ "message": "..." }`.

---

## Statistik

### POST /stats/daily — STK-03 (upsert)

Mengirim beberapa ringkasan harian sekaligus (maks. 31). Kunci upsert: `(user, device_id, day)`; mengirim hari yang sama lagi menimpa nilainya.
```json
{
  "device_id": 7,
  "summaries": [
    {
      "day": "2026-11-16",
      "screen_minutes": 120,
      "avg_blink_rate": 14.5,
      "avg_distance_cm": null,
      "avg_fatigue_score": 32.0,
      "alerts_count": 4,
      "breaks_taken": 3
    }
  ]
}
```
- `device_id` wajib, milik pengguna · `day` wajib `YYYY-MM-DD`, tidak boleh dobel dalam satu request.
- `screen_minutes` 0–1440 · `avg_blink_rate` 0–200 · `avg_distance_cm` 0–500 · `avg_fatigue_score` 0–100 (ketiganya boleh `null`) · `alerts_count`, `breaks_taken` ≥ 0.
- Hanya angka. Field lain diabaikan.

**200 OK** — klien lalu menandai `daily_summaries.synced = 1` untuk hari-hari ini.
```json
{ "message": "Ringkasan harian tersimpan.", "synced_days": ["2026-11-16"] }
```

### GET /stats?range=7|30 — UC-17

`range` opsional, `7` (bawaan) atau `30`. Rentang berakhir hari ini menurut zona waktu akun. Hanya hari yang punya data yang dikembalikan.
Bila beberapa perangkat mengirim hari yang sama: `screen_minutes`, `alerts_count`, `breaks_taken` dijumlahkan; rata-rata ditimbang dengan `screen_minutes`.

**200 OK**
```json
{
  "range": 7,
  "from": "2026-11-10",
  "to": "2026-11-16",
  "days": [
    {
      "day": "2026-11-16",
      "screen_minutes": 120,
      "avg_blink_rate": 12.0,
      "avg_distance_cm": 55.0,
      "avg_fatigue_score": 32.0,
      "alerts_count": 3,
      "breaks_taken": 2,
      "devices": 2
    }
  ]
}
```
**422** bila `range` bukan 7 atau 30.

---

## Saran AI (DOCS_SPEC §17)

### POST /ai/advice

Server meneruskan **hanya angka ringkasan** ini ke Gemini. Nama, email, ID pengguna, gambar, dan field lain tidak pernah diteruskan. Prompt & respons tidak disimpan.
```json
{ "fatigue_score": 45, "blink_rate": 9.5, "perclos": 0.08, "distance_cm": 42, "screen_minutes": 35 }
```
- `fatigue_score` wajib, int 0–100 · `blink_rate` 0–200 · `perclos` 0–1 · `distance_cm` 0–500 · `screen_minutes` int 0–1440 (semua opsional/`null` kecuali skor).

**200 OK**
```json
{ "advice": "• Kedipkan mata perlahan 10 kali...\n• Mundur sedikit dari layar..." }
```
- **429** batas pemakaian per pengguna tercapai (bawaan 10 per jam, `AI_ADVICE_MAX_PER_HOUR`):
  `{ "message": "Batas pemakaian Saran AI tercapai. Coba lagi nanti." }`
- **503** `GEMINI_API_KEY` kosong atau Gemini gagal: `{ "message": "Layanan AI sedang tidak tersedia." }`

Klien menampilkan saran statis untuk semua error.
