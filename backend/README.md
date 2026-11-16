# VisionGuard Backend (Laravel)

REST API untuk aplikasi VisionGuard: akun, perangkat, Hari Pemantauan AI, kredit (ledger),
statistik harian, dan Saran AI (proxy Gemini). Acuan: `../DOCS_SPEC.md` §8, §11, §12.2, §13.2, §17
dan kontrak JSON `../API_CONTRACT.md`.

- Laravel 13, PHP ≥ 8.3, Laravel Sanctum (token API), MySQL 8.
- Tidak ada kolom gambar di tabel mana pun. Saldo kredit selalu `SUM(credit_ledger.delta)`.
- Status: **Tahap A** (lihat `../ROADMAP.md`). Midtrans, panel admin Filament, dan reset kata sandi menyusul di Tahap B.

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
   Isi `DB_USERNAME` / `DB_PASSWORD` di `.env`. Opsional: `GEMINI_API_KEY` untuk Saran AI.
   `.env` sudah di-ignore Git; **jangan di-commit**.
4. Buat tabel & data awal:
   ```bash
   php artisan migrate:fresh --seed
   ```
5. Jalankan server:
   ```bash
   php artisan serve            # http://127.0.0.1:8000/api
   ```
   Atau lewat situs Herd (`herd link` di folder ini → `http://backend.test/api`).

## Akun & data awal (seeder)

| Akun | Email | Sandi | Role |
|---|---|---|---|
| Admin | `admin@visionguard.id` | `password123` | admin |
| Demo | `demo@visionguard.id` | `password123` | user |

Paket kredit aktif: Paket Hemat (5 kredit, Rp15.000), Paket Reguler (12, Rp30.000), Paket Hemat Plus (30, Rp65.000).

## Variabel `.env` khusus VisionGuard

| Variabel | Bawaan | Keterangan |
|---|---|---|
| `DB_DATABASE` | `visionguard` | MySQL lokal |
| `VISIONGUARD_DEFAULT_TIMEZONE` | `Asia/Jakarta` | Zona waktu akun bila tidak dikirim saat registrasi |
| `CORS_ALLOWED_ORIGINS` | `*` | Pengembangan: `*`. Produksi: daftar origin dipisah koma |
| `GEMINI_API_KEY` | kosong | Kosong → `POST /ai/advice` menjawab 503, klien memakai saran statis |
| `GEMINI_MODEL` | `gemini-2.0-flash` | |
| `AI_ADVICE_MAX_PER_HOUR` | `10` | Batas Saran AI per pengguna per jam (429) |

Aturan bisnis lain (kuota gratis 2/bulan, login ditahan 5 menit setelah 5× gagal, rentang 7/30 hari) ada di `config/visionguard.php`.

## Endpoint (`/api`)

| Method | Path | Auth | Keterangan |
|---|---|---|---|
| POST | `/auth/register` | publik | 201 + token; 422 email terpakai |
| POST | `/auth/login` | publik | 200 + token + `device_id`; 401; 429 setelah 5× gagal |
| POST | `/auth/logout` | token | Cabut token perangkat ini |
| GET | `/me` | token | Profil |
| DELETE | `/me` | token | Hapus akun (body `password`); 403 sandi salah |
| POST | `/monitoring-days/activate` | token | Algoritma §8.2; 402 kuota & kredit habis |
| GET | `/credits/status` | token | Kuota gratis, saldo, status hari ini |
| GET | `/credit-packages` | token | Paket aktif |
| GET | `/credits/history` | token | Order + mutasi ledger |
| POST | `/stats/daily` | token | Upsert ringkasan harian (batch) |
| GET | `/stats?range=7\|30` | token | Tren |
| POST | `/ai/advice` | token | Proxy Gemini, hanya angka ringkasan; 429/503 |

Contoh request/response lengkap: `../API_CONTRACT.md`.

```bash
curl -X POST http://127.0.0.1:8000/api/auth/login -H "Content-Type: application/json" \
     -d '{"email":"demo@visionguard.id","password":"password123","platform":"windows","device_name":"dev"}'
curl http://127.0.0.1:8000/api/credits/status -H "Authorization: Bearer <token>"
```

## Test

```bash
php artisan test          # SQLite in-memory (phpunit.xml), tidak menyentuh DB visionguard
./vendor/bin/pint --test  # gaya kode
```

## Struktur

```
app/
├── Exceptions/AiUnavailableException.php
├── Http/
│   ├── Controllers/Api/   # Auth, Account, MonitoringDay, Credit, Stats, AiAdvice
│   ├── Middleware/ForceJsonResponse.php
│   ├── Requests/          # Form Request per endpoint
│   └── Resources/         # User, CreditPackage, Order, LedgerEntry
├── Models/                # User, Device, CreditPackage, Order, CreditLedger (append-only), MonitoringDay, DailyStat
├── Providers/AppServiceProvider.php   # rate limiter ai-advice, JSON tanpa wrapper
└── Services/              # MonitoringDayService (§8.2), StatsService, AccountService,
                           # DeviceService, LoginThrottle, GeminiAdviceService
config/visionguard.php     # aturan bisnis
database/migrations/       # users (§12.2) + 2026_11_16_130000_create_visionguard_tables.php
database/seeders/DatabaseSeeder.php
tests/Feature/             # AuthTest, MonitoringDayTest, CreditTest, StatsTest, AccountTest, AiAdviceTest
```
