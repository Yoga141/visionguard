# HANDOFF — VisionGuard

Dokumen serah terima (Tahap F, 23 November 2026). Untuk pengembang atau AI agent berikutnya.
Urutan baca: **`AGENTS.md` → `DOCS_SPEC.md` → dokumen ini → `ROADMAP.md`**. Bila bertentangan,
`DOCS_SPEC.md` yang berlaku.

---

## 1. Ringkasan

VisionGuard adalah aplikasi Flutter (Windows, macOS, Android, iOS) untuk deteksi dini kelelahan mata
digital. Kamera dipakai *on-device* untuk menghitung blink rate (BR), PERCLOS, dan jarak wajah ke layar,
lalu digabung menjadi skor 0–100 yang memicu pengingat. Backend Laravel (`backend/`) mengurus akun,
kredit (ledger), pembayaran Midtrans, statistik, Saran AI (proxy Gemini), dan panel admin Filament.

Status per kebutuhan: tabel audit di **`README.md`**. Per tahap: **`ROADMAP.md`**.

**Distribusi v1.0:** di luar toko aplikasi — APK langsung (Android) dan installer Windows — dengan
pembayaran Midtrans (DOCS_SPEC §4.5, §16 #36). Saran AI adalah fitur resmi (DOCS_SPEC §8.9, SAI-01..03).

## 2. Arsitektur

```
┌──────────────────────────── Flutter (lib/) ────────────────────────────┐
│ app/ (router go_router, MainShell)    shared/widgets (badge kamera, ?) │
│ features/*  data → application (Riverpod Notifier) → presentation      │
│   auth · onboarding · calibration · monitoring · reminders · stats     │
│   credits · ai_assistant · settings · background · eye_check · help    │
│ cv_engine/ (tanpa UI): CameraSource → FaceAnalyzer → BlinkAnalyzer,     │
│   DistanceEstimator → SessionEvaluator/FatigueScorer                   │
│   FaceAnalyzer = MediaPipeFaceAnalyzer (TFLite) | DummyFaceAnalyzer     │
│ core/: constants (cv_constants = satu-satunya tempat ambang CV),       │
│   database (drift SQLite, 6 tabel §12.3), network (Dio + Sanctum)      │
└───────────────┬────────────────────────────────────────────────────────┘
                │ HTTPS JSON (API_CONTRACT.md), token Sanctum
┌───────────────▼──────────── Laravel 13 (backend/) ─────────────────────┐
│ Controllers/Api → Form Requests → Services (MonitoringDayService §8.2, │
│ PaymentNotificationService, CreditAdjustmentService, StatsService,     │
│ GeminiAdviceService, …) → Models → MySQL 8 (7 tabel §12.2)             │
│ Filament 5 /admin · halaman web pembayaran & reset sandi               │
└───────┬─────────────────────────────┬──────────────────────────────────┘
        │ Snap + Status API           │ angka ringkasan saja (§8.9)
     Midtrans                      Gemini API (Saran AI, DOCS_SPEC §8.9)
```

Prinsip yang tidak boleh dilanggar:
- **Frame kamera tidak pernah disimpan atau dikirim.** Database hanya angka (PRV-01).
- **Saldo = `SUM(credit_ledger.delta)` di server.** Kredit pembelian hanya dari notifikasi Midtrans
  bersignature (`PaymentNotificationService`); klien tidak pernah menambah saldo (KMN-03).
- `lib/cv_engine/` tidak meng-import UI; konstanta CV hanya di `cv_constants.dart`.
- Key (Midtrans, Gemini, SMTP) hanya di `backend/.env` (di-ignore Git).

Alur penting (detail di `AGENTS.md` §4): aktivasi hari & kredit, pengingat (skor tiap 10 dtk, RuleEngine tiap 1 dtk → ≤ 2 dtk, KNR-03),
statistik & sinkron, beli kredit, latar belakang (tray/foreground service), kamera bentrok.

## 3. Menjalankan

### Prasyarat
Flutter SDK (Dart ^3.5; dipakai Flutter 3.47.1), Visual Studio 2022 + "Desktop development with C++" +
komponen **C++ ATL** (Windows), Android SDK + HP Android 8.0+, Laravel Herd (PHP ≥ 8.3, Composer),
MySQL 8. macOS/iOS butuh Mac + Xcode.

### Backend
```bash
cd backend
composer install
cp .env.example .env && php artisan key:generate     # isi DB_USERNAME / DB_PASSWORD
php artisan migrate:fresh --seed                      # database MySQL `visionguard`
php artisan serve                                     # http://127.0.0.1:8000/api · /admin
# HP fisik di jaringan yang sama: php artisan serve --host=0.0.0.0
```
Detail variabel `.env`: `backend/README.md`.

### Flutter
```bash
flutter pub get
flutter run -d windows                                # backend http://127.0.0.1:8000/api
flutter run -d <id-hp>                                # emulator: http://10.0.2.2:8000/api (bawaan)
flutter run -d <id-hp> --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api
flutter run -d windows --dart-define=USE_REMOTE_API=false   # tanpa server (repository tiruan)
```

### Verifikasi
```bash
flutter analyze && flutter test            # 0 issue · 217 test
flutter test --coverage                    # lcov di coverage/lcov.info
flutter build apk --debug
cd backend && php artisan test && ./vendor/bin/pint --test    # 91 test
```

### Uji pembayaran Midtrans Sandbox
1. Isi `MIDTRANS_SERVER_KEY`, `MIDTRANS_CLIENT_KEY`, `MIDTRANS_SIGNATURE_SECRET_KEY` di `backend/.env`
   (dashboard Sandbox → Settings → Access Keys; Server Key berizin Snap Checkout: Write + Core API: Read).
2. `php artisan config:clear` lalu `php artisan payments:check --ping` → harus `Mode efektif : midtrans`
   dan `Server key DITERIMA`. Nilai key tidak pernah dicetak.
3. Tunnel publik (`ngrok http 8000` / `cloudflared`) → Payment Notification URL di dashboard:
   `https://<tunnel>/api/payments/midtrans/notification`.
4. Aplikasi → Kredit → Beli → bayar di browser via Midtrans Payment Simulator → kembali ke aplikasi →
   "Muat ulang status". Cek order di `/admin` → Transaksi.
5. Tanpa akun Midtrans: `PAYMENT_MODE=simulation` (halaman `/payments/simulate/{order_code}`; ditolak di
   produksi).

Langkah lengkap: `backend/README.md` § "Uji Midtrans Sandbox".

## 4. Akun demo & admin (seeder, hanya untuk pengembangan)

| Akun | Email | Sandi | Akses |
|---|---|---|---|
| Admin | `admin@visionguard.id` | `password123` | `/admin` (Filament) |
| Demo | `demo@visionguard.id` | `password123` | Aplikasi |

Ganti/hapus akun ini sebelum produksi. Paket seeder: Hemat (5 kredit, Rp15.000), Reguler (12, Rp30.000),
Hemat Plus (30, Rp65.000).

## 5. Status fitur (ringkas)

| Area | Status |
|---|---|
| Akun, kalibrasi (logika), aktivasi hari & kredit, pengingat PNG-01..07 (≤ 2 dtk, KNR-03), statistik, Saran AI (SAI-01..03), admin | ✅ kode + test |
| Deteksi wajah asli (MediaPipe) | 🟡 Android/iOS terpasang, belum diuji di HP; Windows mode simulasi |
| Latar belakang (tray Windows, foreground service Android), Sesi Cek Mata, autostart | 🟡 kode + test, uji manual belum |
| Pembayaran Midtrans Sandbox | 🟡 teruji otomatis & simulasi; transaksi Sandbox asli belum |
| Pengukuran mutu (fps, CPU/RAM, akurasi, baterai, USB-01) | ⏳ belum diukur |

Coverage (PML-01): `lib/cv_engine/` 77,5 %, `lib/features/credits/` 88,7 %, seluruh `lib/` 61,0 %.
Coverage backend belum terukur (PHP tanpa Xdebug/PCOV).

## 6. Batasan yang diketahui

- **iOS & macOS** belum pernah di-build: butuh Mac + Xcode. iOS tanpa foreground service kamera; tray &
  autostart macOS belum dibuat.
- **MediaPipe di Windows**: `camera_windows` 0.3.x tidak menyediakan image stream, dan `tflite_flutter`
  Windows butuh `libtensorflowlite_c-win.dll` manual. Windows memakai `DummyFaceAnalyzer` berlabel
  "Mode simulasi" (pratinjau kamera tetap asli).
- **Kamera Android di latar**: `camera_android_camerax` terikat ke Activity; saat aplikasi tidak terlihat
  frame berhenti dan pemantauan otomatis dijeda (§16 #32). Layar mati → pemantauan berhenti.
- **Pembayaran di toko aplikasi**: v1.0 hanya untuk distribusi di luar toko. Rilis ke Google Play /
  App Store **wajib** Google Play Billing / In-App Purchase untuk pembelian kredit (§16 #36); belum dibuat.
- `flutter build windows` setelah Tahap E belum terverifikasi (build terhenti karena memori sistem).
- Versi paket ditahan: `tray_manager` 0.8.x / `window_manager` 0.6.x (versi baru butuh Flutter ≥ 3.50);
  `launch_at_startup` tidak dipakai (bentrok `win32` 6).
- Reset sandi teruji dengan `MAIL_MAILER=log`; SMTP asli belum diuji. Backend belum dideploy (VPS/TLS §4.1).

## 7. Pekerjaan lanjutan (berprioritas)

| Prioritas | Pekerjaan |
|---|---|
| P1 | Uji MediaPipe di HP Android: kedipan vs hitung manual 1 mnt, jarak 30/50/80 cm (±5 cm), yaw > 30°, fps ≥ 10; cek arah rotasi kamera depan |
| P1 | Uji transaksi Midtrans Sandbox end-to-end (notifikasi via tunnel) |
| P1 | Jalankan `flutter build windows` + uji tray, tutup jendela, autostart (login ulang Windows), CPU/RAM di tray (KNR-02) |
| P2 | Uji foreground service, layar mati, Sesi Cek Mata, kamera bentrok di HP Android |
| P2 | Pasang Xdebug/PCOV → `php artisan test --coverage` (target ≥ 70 % untuk `MonitoringDayService`, `CreditAdjustmentService`, notifikasi pembayaran) |
| P2 | Bila akan rilis ke **Google Play / App Store**: implementasikan Google Play Billing (Android) / In-App Purchase (iOS) untuk paket kredit — produk konsumsi per paket, verifikasi token/receipt di server (Google Play Developer API / App Store Server API), kredit ditulis ke `credit_ledger` hanya setelah verifikasi (idempoten), Midtrans tetap untuk build di luar toko. Wajib sebelum unggah ke toko (§16 #36) |
| P2 | Siapkan paket distribusi di luar toko: APK release bertanda tangan + installer Windows (MSIX/`.exe`), backend HTTPS |
| P2 | Deploy backend (Ubuntu 22.04 + Nginx + PHP-FPM + TLS, §4.1), ganti akun seeder, `CORS_ALLOWED_ORIGINS` |
| P3 | Revisi SRS/SDD menurut DOCS_SPEC §18 (Saran AI sudah resmi di DOCS_SPEC §8.9) |
| P3 | Deteksi wajah Windows (plugin kamera dengan frame stream + DLL TFLite); build & uji macOS/iOS |
| P3 | Kamera Android di latar (CameraX + inferensi di dalam service, native) |
| P3 | Uji akurasi berlabel (AKR-01/02) dan waktu onboarding (USB-01) |

## 8. Aturan proyek (wajib)

Ringkasan dari `AGENTS.md` §6. Yang mengikat adalah `AGENTS.md`.

1. **Agent DILARANG** menjalankan `git commit`, `git push`, `git reset`, `git clean`, `git rebase`,
   `git checkout -- .`, atau perintah lain yang mengubah riwayat/remote, dan **tidak boleh** menambahkan
   baris `Co-Authored-By`. Commit & push hanya oleh pengguna.
2. Jangan upgrade versi major dependensi tanpa izin. Paket baru boleh bila dibutuhkan; sebutkan, dan
   tanyakan bila ada beberapa pilihan setara.
3. Hal yang belum diatur `DOCS_SPEC.md` atau masuk §16 berstatus terbuka → tanyakan pengguna.
4. Setelah mengubah kode: `flutter analyze` + `flutter test` bersih; bila menyentuh `backend/`, juga
   `php artisan test` + `./vendor/bin/pint --test`.
5. Key tidak pernah diminta, ditebak, ditulis di kode/test/dokumen, atau dicetak.
6. Satu tahap per sesi; perbarui `ROADMAP.md` (status, kriteria, catatan sesi) di akhir.
