# VisionGuard Backend (Laravel)

REST API + panel admin untuk aplikasi VisionGuard: akun, perangkat, Hari Pemantauan AI, kredit (ledger),
pembayaran Midtrans, reset kata sandi, statistik harian, dan Saran AI (proxy Gemini).
Acuan: `../DOCS_SPEC.md` §8, §11, §12.2, §13.2, §17 dan kontrak JSON `../API_CONTRACT.md`.

- Laravel 13, PHP ≥ 8.3, Laravel Sanctum (token API), MySQL 8, Filament 5 (panel admin `/admin`).
- Tidak ada kolom gambar di tabel mana pun. Saldo kredit selalu `SUM(credit_ledger.delta)`.
- Status: **Tahap A–B** selesai (lihat `../ROADMAP.md`).

## Instalasi (Windows, Laravel Herd + MySQL lokal)

1. Pasang [Laravel Herd](https://herd.laravel.com) (menyediakan `php` dan `composer`) dan MySQL 8.
2. Buat database:
   ```sql
   CREATE DATABASE visionguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
3. Pasang dependensi & konfigurasi:
   ```bash
   cd backend
   composer install
   cp .env.example .env
   php artisan key:generate
   ```
   Isi `DB_USERNAME` / `DB_PASSWORD` di `.env`. Opsional: key Midtrans (lihat di bawah) dan `GEMINI_API_KEY`.
   `.env` sudah di-ignore Git; **jangan di-commit**.
4. Buat tabel & data awal:
   ```bash
   php artisan migrate:fresh --seed
   ```
5. Jalankan server:
   ```bash
   php artisan serve            # API: http://127.0.0.1:8000/api · Admin: http://127.0.0.1:8000/admin
   ```
   Atau lewat situs Herd (`herd link` di folder ini → `http://backend.test`).

## Akun & data awal (seeder)

| Akun | Email | Sandi | Role |
|---|---|---|---|
| Admin | `admin@visionguard.id` | `password123` | admin (bisa masuk `/admin`) |
| Demo | `demo@visionguard.id` | `password123` | user |

Paket kredit aktif: Paket Hemat (5 kredit, Rp15.000), Paket Reguler (12, Rp30.000), Paket Hemat Plus (30, Rp65.000).

## Variabel `.env` khusus VisionGuard

| Variabel | Bawaan | Keterangan |
|---|---|---|
| `DB_DATABASE` | `visionguard` | MySQL lokal |
| `VISIONGUARD_DEFAULT_TIMEZONE` | `Asia/Jakarta` | Zona waktu akun bila tidak dikirim saat registrasi |
| `CORS_ALLOWED_ORIGINS` | `*` | Pengembangan: `*`. Produksi: daftar origin dipisah koma |
| `PAYMENT_MODE` | `midtrans` | `midtrans` atau `simulation` (lihat bagian pembayaran) |
| `MIDTRANS_SERVER_KEY` | kosong | Kosong → otomatis mode `simulation` + peringatan di log |
| `MIDTRANS_CLIENT_KEY` | kosong | Disimpan untuk klien Snap; belum dipakai server |
| `MIDTRANS_MERCHANT_ID` | kosong | Informasi akun; belum dipakai server |
| `MIDTRANS_IS_PRODUCTION` | `false` | `false` = Sandbox |
| `MAIL_MAILER` | `log` | Email reset sandi ditulis ke `storage/logs/laravel.log` |
| `GEMINI_API_KEY` | kosong | Kosong → `POST /ai/advice` menjawab 503, klien memakai saran statis |
| `GEMINI_MODEL` | `gemini-2.0-flash` | |
| `AI_ADVICE_MAX_PER_HOUR` | `10` | Batas Saran AI per pengguna per jam (429) |

Aturan bisnis lain (kuota gratis 2/bulan, login ditahan 5 menit setelah 5× gagal, rentang 7/30 hari) ada di `config/visionguard.php`.

## Mengisi API Key Midtrans

Key **tidak pernah** ditulis di kode, test, atau dokumen. Isi sendiri di `backend/.env`:

1. Masuk ke dashboard Midtrans, pilih lingkungan **Sandbox**.
2. Buka **Settings → Access Keys**.
3. Salin nilainya ke variabel berikut di `backend/.env`:
   ```dotenv
   PAYMENT_MODE=midtrans
   MIDTRANS_SERVER_KEY=
   MIDTRANS_CLIENT_KEY=
   MIDTRANS_MERCHANT_ID=
   MIDTRANS_IS_PRODUCTION=false
   ```
4. Muat ulang konfigurasi: `php artisan config:clear`, lalu jalankan ulang `php artisan serve`.

Kode membaca key hanya lewat `config('services.midtrans.*')`. Test memakai key dummy dari `tests/` dan
mengosongkan key di `phpunit.xml`, sehingga key asli di `.env` tidak pernah dipakai saat `php artisan test`.

### Mode pembayaran

| `PAYMENT_MODE` | `MIDTRANS_SERVER_KEY` | Yang dipakai |
|---|---|---|
| `midtrans` | terisi | Midtrans Snap (Sandbox bila `MIDTRANS_IS_PRODUCTION=false`) |
| `midtrans` | kosong | **Simulasi** + peringatan di log |
| `simulation` | apa saja | **Simulasi**: `redirect_url` membuka `/payments/simulate/{order_code}` dengan tombol Bayar / Kedaluwarsa / Batal / Tolak |

Simulasi mengirim notifikasi berformat Midtrans bersignature valid ke logika yang sama, jadi alur kredit
bisa diuji tanpa akun Midtrans. Simulasi **ditolak** bila `APP_ENV=production`.

## Uji Midtrans Sandbox langkah demi langkah

1. Isi key Sandbox (bagian di atas) dan jalankan server:
   ```bash
   php artisan serve          # port 8000
   ```
2. Buka tunnel publik agar Midtrans bisa mengirim notifikasi ke laptop:
   ```bash
   ngrok http 8000
   ```
   Catat URL HTTPS-nya, mis. `https://abcd-1234.ngrok-free.app`.
3. Di dashboard Midtrans Sandbox → **Settings → Payment → Notification URL**, isi
   **Payment Notification URL**:
   ```
   https://<ngrok>/api/payments/midtrans/notification
   ```
   Opsional (Snap Preferences → redirect URL): Finish `https://<ngrok>/payments/finish`,
   Unfinish `https://<ngrok>/payments/unfinish`, Error `https://<ngrok>/payments/error`.
4. Beli paket dari aplikasi (menu Kredit → Beli). Tanpa aplikasi, bisa dengan curl:
   ```bash
   curl -X POST http://127.0.0.1:8000/api/auth/login -H "Content-Type: application/json" \
        -d '{"email":"demo@visionguard.id","password":"password123","platform":"windows","device_name":"dev"}'
   curl -X POST http://127.0.0.1:8000/api/orders -H "Authorization: Bearer <token>" \
        -H "Content-Type: application/json" -d '{"package_id":1}'
   ```
   Buka `redirect_url` dari respons, pilih metode (mis. QRIS atau Virtual Account).
5. Bayar memakai **Midtrans Payment Simulator** (`https://simulator.sandbox.midtrans.com`): pilih metode
   yang sama, tempel kode VA / URL QRIS, lalu bayar.
6. Midtrans mengirim notifikasi `settlement` → saldo bertambah. Cek:
   ```bash
   curl http://127.0.0.1:8000/api/orders/<order_code> -H "Authorization: Bearer <token>"
   curl http://127.0.0.1:8000/api/credits/status -H "Authorization: Bearer <token>"
   ```
   `GET /orders/{order_code}` juga mengecek Status API Midtrans bila notifikasi belum masuk.
7. Buka `http://127.0.0.1:8000/admin` (admin seeder) → **Transaksi**: order berstatus *Berhasil*
   dengan `payment_type` dan waktu bayar; **Pengguna**: saldo akun demo bertambah.

Notifikasi dengan signature salah ditolak (403) dan dicatat di `storage/logs/laravel.log`.

## Reset kata sandi

- `POST /api/auth/forgot-password` mengirim email berisi tautan `/reset-password/{token}?email=...`
  (berlaku 60 menit). Pengguna mengisi sandi baru dua kali di halaman web tersebut.
- Bawaan `MAIL_MAILER=log`: isi email (termasuk tautan) ada di `storage/logs/laravel.log`.
- **SMTP Gmail** (opsional): aktifkan verifikasi 2 langkah di akun Google, buat **App Password**, lalu isi
  sendiri di `backend/.env`:
  ```dotenv
  MAIL_MAILER=smtp
  MAIL_HOST=smtp.gmail.com
  MAIL_PORT=587
  MAIL_SCHEME=null
  MAIL_USERNAME=
  MAIL_PASSWORD=
  MAIL_FROM_ADDRESS=
  ```
  `MAIL_PASSWORD` diisi App Password, bukan sandi akun Google.

## Panel admin (`/admin`)

Hanya akun `role = admin`. Login dengan akun admin seeder.

- **Paket Kredit (A-01):** tambah, ubah, aktifkan/nonaktifkan. Paket yang pernah dibeli tidak bisa dihapus.
- **Transaksi (A-02):** daftar order (hanya baca), filter status & tanggal, kolom metode & waktu bayar.
- **Pengguna (A-03):** daftar + saldo; aksi **Sesuaikan kredit** (delta ±, alasan wajib, saldo akhir tidak boleh negatif) → ledger `adjustment`.

## Endpoint (`/api`)

| Method | Path | Auth | Keterangan |
|---|---|---|---|
| POST | `/auth/register` | publik | 201 + token; 422 email terpakai |
| POST | `/auth/login` | publik | 200 + token + `device_id`; 401; 429 setelah 5× gagal |
| POST | `/auth/forgot-password` | publik | Kirim tautan reset; 404 email tidak terdaftar; 429 |
| POST | `/auth/reset-password` | publik | Sandi baru (2×); 422 token tidak valid/kedaluwarsa |
| POST | `/auth/logout` | token | Cabut token perangkat ini |
| GET | `/me` | token | Profil |
| DELETE | `/me` | token | Hapus akun (body `password`); 403 sandi salah |
| POST | `/monitoring-days/activate` | token | Algoritma §8.2; 402 kuota & kredit habis |
| GET | `/credits/status` | token | Kuota gratis, saldo, status hari ini |
| GET | `/credit-packages` | token | Paket aktif |
| GET | `/credits/history` | token | Order + mutasi ledger |
| POST | `/orders` | token | Order pending + Snap token/redirect_url; 422 paket nonaktif; 503 |
| GET | `/orders/{order_code}` | token | Status order (cek Status API bila pending); 404 |
| POST | `/payments/midtrans/notification` | publik (signature) | Notifikasi Midtrans; 403 signature salah |
| POST | `/stats/daily` | token | Upsert ringkasan harian (batch) |
| GET | `/stats?range=7\|30` | token | Tren |
| POST | `/ai/advice` | token | Proxy Gemini, hanya angka ringkasan; 429/503 |

Halaman web: `/payments/finish`, `/payments/unfinish`, `/payments/error`, `/payments/simulate/{order_code}`,
`/reset-password/{token}`. Contoh request/response lengkap: `../API_CONTRACT.md`.

## Test

```bash
php artisan test          # SQLite in-memory (phpunit.xml), Http::fake untuk Midtrans/Gemini
./vendor/bin/pint --test  # gaya kode
```

## Struktur

```
app/
├── Exceptions/AiUnavailableException.php
├── Filament/Resources/    # CreditPackages (A-01), Orders (A-02), Users (A-03 + aksi Sesuaikan kredit)
├── Http/
│   ├── Controllers/Api/   # Auth, PasswordReset, Account, MonitoringDay, Credit, Order,
│   │                      # PaymentNotification, Stats, AiAdvice
│   ├── Controllers/Web/   # PaymentPage (finish/unfinish/error/simulate), PasswordResetPage
│   ├── Middleware/ForceJsonResponse.php
│   ├── Requests/          # Form Request per endpoint
│   └── Resources/         # User, CreditPackage, Order, LedgerEntry
├── Models/                # User (FilamentUser), Device, CreditPackage, Order, CreditLedger (append-only),
│                          # MonitoringDay, DailyStat
├── Notifications/ResetPasswordNotification.php
├── Providers/             # AppServiceProvider (rate limiter, PaymentManager), Filament/AdminPanelProvider
└── Services/              # MonitoringDayService (§8.2), OrderService, CreditAdjustmentService (§8.5),
    │                      # PasswordResetService, StatsService, AccountService, DeviceService,
    │                      # LoginThrottle, GeminiAdviceService
    └── Payments/          # PaymentManager (mode), MidtransGateway, SimulationGateway,
                           # PaymentNotificationService (signature SHA-512, idempoten)
config/visionguard.php     # aturan bisnis + payment_mode
resources/views/           # payments/*, auth/reset-password*, layouts/plain
database/migrations/       # users (§12.2) + 2026_11_16_130000_create_visionguard_tables.php
tests/Feature/             # Auth, MonitoringDay, Credit, Stats, Account, AiAdvice, PasswordReset,
                           # AdminPanel, Payments/{Order, PaymentNotification, PaymentMode}
```
