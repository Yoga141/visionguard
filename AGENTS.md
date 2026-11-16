# AGENTS.md — VisionGuard

Instruksi tunggal untuk semua AI coding assistant (Claude Code, OpenCode, Antigravity, dll.).

## 1. Wajib dibaca dulu

- **Baca `DOCS_SPEC.md` sebelum mengerjakan apa pun.** Dokumen itu adalah sumber kebenaran fitur, alur, database, API, dan aturan bisnis (diringkas dari SRS & SDD VisionGuard v1.0).
- Jika kode bertentangan dengan `DOCS_SPEC.md`, **ikuti `DOCS_SPEC.md`**.
- Jika suatu hal **belum diatur** di `DOCS_SPEC.md` atau termasuk **§16 (Inkonsistensi & Keputusan Terbuka)**, **tanyakan dulu** ke pengguna sebelum memutuskan.
- **Baca `ROADMAP.md`** untuk status progress, urutan tahap berikutnya (A–F), kriteria selesai, dan cara verifikasinya. Kerjakan satu tahap per sesi.
- **Setiap akhir tahap, perbarui status di `ROADMAP.md`:** kolom status di tabel "Ringkasan tahap" dan baris `Status:` tahap itu (belum/sebagian/selesai), centang kriteria yang terpenuhi, dan isi satu baris "Catatan sesi".

## 2. Ringkasan proyek

VisionGuard adalah aplikasi Flutter (Windows, macOS, Android, iOS) untuk deteksi dini kelelahan mata digital. Kamera dipakai untuk menghitung blink rate, PERCLOS, dan jarak wajah ke layar secara *on-device*, lalu digabung menjadi skor kelelahan 0–100 yang memicu pengingat. Backend Laravel + MySQL ada di folder `backend/` (Tahap A–B: akun, kredit, statistik, Saran AI, Midtrans, panel admin Filament, reset sandi).

## 3. Stack

- **Flutter** (Dart SDK `^3.5.0`)
- **State management:** `flutter_riverpod` 2.x
- **Navigasi:** `go_router` 14
- **Kamera:** `camera` / `camera_windows`
- **Backend (`backend/`):** Laravel 13 (PHP ≥ 8.3, Laravel Herd) + Sanctum + MySQL 8 (`DB_DATABASE=visionguard`) + **Filament 5** (panel admin `/admin`, role admin) + Midtrans Snap lewat HTTP client (`PAYMENT_MODE=midtrans|simulation`; server key kosong → simulation). Kontrak JSON di `API_CONTRACT.md` (root); aturan bisnis server di `backend/config/visionguard.php`. `backend/.env` (kredensial DB, `GEMINI_API_KEY`) tidak boleh di-commit; contoh di `backend/.env.example`. Panduan: `backend/README.md`.
- **Jaringan:** `dio` (REST JSON ke Laravel) + `flutter_secure_storage` (token Sanctum) + `url_launcher` (halaman bayar Midtrans di browser). Terhubung ke `backend/` secara bawaan (Tahap C).
- **Saran AI (fitur tambahan, DOCS_SPEC §17):** bawaan lewat backend `POST /ai/advice`. `google_generative_ai` hanya untuk build debug dengan `USE_REMOTE_API=false` + `--dart-define=GEMINI_API_KEY=...`. `.env` **bukan** lagi asset Flutter dan `flutter_dotenv` sudah dilepas; jangan dikembalikan.
- **Database lokal:** SQLite via `drift` + `drift_flutter` (file di folder `getApplicationSupportDirectory` dari `path_provider`), skema persis DOCS_SPEC §12.3. Kode `app_database.g.dart` dihasilkan `drift_dev` + `build_runner`.
- **Notifikasi pengingat:** `flutter_local_notifications` 22.x (Windows & Android, aksi Tunda). Gagal/tidak didukung/izin ditolak → pop-up dalam aplikasi. Android memakai *core library desugaring* & izin `POST_NOTIFICATIONS`.
- **Grafik:** `fl_chart` 1.x (tren 7/30 hari di halaman Statistik).
- Direncanakan (masih dikomentari di `pubspec.yaml`): `tflite_flutter`
- **Firebase tidak dipakai** (DOCS_SPEC §16 #13). Jangan menambahkannya kembali tanpa izin.

## 4. Struktur

### 4.1 `backend/` (Laravel)

```
backend/
├── app/Filament/Resources/    # CreditPackages (A-01), Orders (A-02, baca saja), Users (A-03 + Sesuaikan kredit)
├── app/Http/Controllers/Api/  # Auth, PasswordReset, Account, MonitoringDay, Credit, Order,
│                              # PaymentNotification, Stats, AiAdvice
├── app/Http/Controllers/Web/  # PaymentPage (finish/unfinish/error/simulate), PasswordResetPage
├── app/Http/Requests/         # Form Request per endpoint (validasi)
├── app/Http/Resources/        # format JSON (datar, tanpa "data")
├── app/Http/Middleware/       # ForceJsonResponse (semua /api menjawab JSON)
├── app/Models/                # User (creditBalance, freeQuotaRemaining), Device, CreditPackage,
│                              # Order, CreditLedger (append-only), MonitoringDay, DailyStat
├── app/Services/              # MonitoringDayService (§8.2, DB transaction + lockForUpdate),
│                              # StatsService, AccountService (hapus/anonimkan), DeviceService,
│                              # LoginThrottle (5× gagal → 5 menit), GeminiAdviceService, OrderService,
│                              # CreditAdjustmentService (§8.5), PasswordResetService
├── app/Services/Payments/     # PaymentManager (mode), MidtransGateway, SimulationGateway,
│                              # PaymentNotificationService (signature SHA-512, idempoten)
├── resources/views/           # halaman web pembayaran & form reset sandi
├── config/visionguard.php     # satu-satunya tempat aturan bisnis server (kuota, lockout, rate limit AI)
├── database/migrations/       # 7 tabel §12.2 (+ orders.created_at, §16 #18)
├── database/seeders/          # admin, demo, 3 paket aktif
├── routes/api.php, routes/web.php
└── tests/Feature/             # Auth, MonitoringDay, Credit, Stats, Account, AiAdvice, PasswordReset,
                               # AdminPanel, Payments/{Order, PaymentNotification, PaymentMode}
```

Aturan backend: saldo selalu `SUM(credit_ledger.delta)`; ledger tidak pernah di-update/delete (kecuali anonimisasi FK saat hapus akun); tidak ada kolom gambar; hanya angka ringkasan §17.2 yang diteruskan ke Gemini; kredit pembelian hanya dari notifikasi bersignature valid (`PaymentNotificationService`), jangan menambah kredit di tempat lain. **Key (Midtrans, Gemini, SMTP) hanya di `backend/.env`**: jangan diminta, ditebak, ditulis di kode/test/dokumen, atau dicetak; akses lewat `config('services.*')`. Test memakai key dummy (`phpunit.xml` mengosongkan key asli). Diagnosis pembayaran: `php artisan payments:check [--ping]` (hanya mode & ADA/KOSONG, tidak pernah mencetak key). Signature notifikasi Midtrans memakai `MIDTRANS_SIGNATURE_SECRET_KEY` (fallback Server Key bila kosong); Server Key hanya untuk otorisasi API (DOCS_SPEC §16 #30). Instruksi AI hanya ada di `AGENTS.md` root ini; **jangan** menambah `CLAUDE.md`/`AGENTS.md` di `backend/` dan jangan memasang Laravel Boost.

### 4.2 `lib/` (Flutter)

```
lib/
├── main.dart
├── app/                  # app.dart, router.dart (go_router + StatefulShellRoute), theme.dart,
│                         # main_shell.dart (menu utama §7.4: bottom nav / navigation rail)
├── core/
│   ├── constants/        # cv_constants.dart — satu-satunya tempat konstanta CV & ambang pengingat
│   │                     # (termasuk cooldown, durasi kondisi, tunda/Mode Fokus, opsi demo)
│   │                     # api_constants.dart — base URL, flag useRemoteApi, timeout
│   │                     # business_constants.dart — aturan kredit (kuota 2/bulan) & statistik
│   │                     # (rentang tren 7/30, minimal 2 hari, data contoh 14 hari)
│   ├── database/         # app_database.dart (6 tabel §12.3) + app_database.g.dart (generated),
│   │                     # database_providers.dart (appDatabaseProvider, dayKey)
│   └── network/          # api_client.dart (Dio + interceptor token), api_exception.dart,
│                         # token_storage.dart (flutter_secure_storage)
├── cv_engine/            # logika CV murni: face_analyzer (interface), dummy_face_analyzer,
│                         # camera_source, blink_analyzer, distance_estimator (median 1 dtk),
│                         # fatigue_scorer (int), session_evaluator (evaluasi 10 dtk, jeda
│                         # wajah hilang PMT-05), cv_providers
├── features/             # feature-first: data / application / presentation
│   ├── ai_assistant/     # Saran AI (§17): data/ai_advice_repository.dart (kontrak + saran statis),
│   │                     # data/gemini_service.dart (DirectGeminiAdviceRepository, dev),
│   │                     # data/api_ai_advice_repository.dart (POST /ai/advice, bawaan),
│   │                     # application/ai_advice_provider.dart,
│   │                     # presentation/ai_advice_card.dart (kartu "Minta saran", Dashboard & Statistik)
│   ├── auth/             # data/auth_repository (kontrak + Fake: login, register, restoreSession,
│   │                     # forgotPassword, deleteAccount, logout), api_auth_repository,
│   │                     # session_store (settings: device_id, profil terakhir, privasi per akun);
│   │                     # application/auth_controller, local_data_cleaner (hapus data lokal);
│   │                     # presentation/splash_page (auto-login), login_page,
│   │                     # forgot_password_page (UC-03), post_login (rute setelah masuk)
│   ├── calibration/      # data/calibration_repository (per camera_id, KLB-04),
│   │                     # calibration_controller, calibration_page
│   ├── credits/          # domain/credit_models.dart (paket, order, ledger, monitoring day, status,
│   │                     # ActivationResult); data/credit_repository.dart (kontrak +
│   │                     # FakeCreditRepository: algoritma §8.2, saldo = SUM ledger),
│   │                     # data/api_credit_repository.dart (status, aktivasi + 402, paket,
│   │                     # riwayat, POST /orders, GET /orders/{code});
│   │                     # application/credit_controller.dart (buy → url_launcher, muat ulang
│   │                     # status order); presentation/credits_page (S-09, kartu order pending)
│   ├── monitoring/       # data/session_repository, metrics_repository (sampel 60 dtk,
│   │                     # retensi 30 hari, ringkasan harian, hari aktif, pengingat istirahat),
│   │                     # alert_repository;
│   │                     # monitoring_controller, dashboard_page
│   ├── onboarding/       # privacy_onboarding_page
│   ├── reminders/        # Pengingat PNG-01..07: domain/reminder.dart (ReminderType berurutan
│   │                     # prioritas + pesan §9.5, ReminderMetrics);
│   │                     # application/rule_engine.dart (aturan, durasi kondisi, cooldown),
│   │                     # timer_service.dart (waktu layar 20-20-20, Mode AI & Timer),
│   │                     # break_verifier.dart (≥15/20 dtk berpaling), reminder_hold.dart
│   │                     # (Tunda & Mode Fokus), reminder_controller.dart (ReminderService:
│   │                     # pop-up, auto-dismiss 15 dtk, catat ke alerts);
│   │                     # data/notification_service.dart (flutter_local_notifications);
│   │                     # presentation/reminder_popup.dart (overlay kanan bawah, ExcludeFocus)
│   ├── settings/         # data/settings_repository (key-value),
│   │                     # application/settings_controller (AppSettings, Sensitivity → τ),
│   │                     # presentation/settings_page (S-10, logout, hapus akun + kata sandi)
│   └── stats/            # data/stats_repository.dart (kontrak + FakeStatsRepository),
│                         # data/api_stats_repository.dart (POST /stats/daily batch, GET /stats),
│                         # application/sync_service.dart (SyncService: kirim daily_summaries pending),
│                         # data/demo_data_seeder.dart (debug: data contoh 14 hari);
│                         # application/stats_controller.dart (agregasi → sinkron → tren);
│                         # presentation/statistics_page (S-08: tab Hari Ini & Tren, fl_chart)
└── shared/
    └── widgets/          # camera_active_badge.dart, coming_soon.dart
```

Test ada di `test/` (`cv_engine_test.dart`, `network_test.dart`, `api_integration_test.dart`, `auth_controller_test.dart`, `ai_advice_test.dart`, `ai_advice_card_test.dart`, `database_test.dart`, `local_storage_flow_test.dart`, `settings_test.dart`, `reminders_test.dart`, `stats_test.dart`, `credits_test.dart`, `widget_test.dart`). Test kredit meng-override `creditRepositoryProvider` (`FakeCreditRepository` dengan jam tiruan); test statistik meng-override `statsRepositoryProvider` dan `statsClockProvider`. Test pengingat memakai `FakeNotifier` (override `systemNotifierProvider`) dan jam tiruan (override `reminderClockProvider`). Test database memakai SQLite in-memory (`AppDatabase(NativeDatabase.memory())`, override `appDatabaseProvider`). Test repository API memakai Dio dengan adapter tiruan (`RouteAdapter` di `api_integration_test.dart`), tanpa server sungguhan. Test yang memakai `AuthController`/`SessionStore` wajib meng-override `appDatabaseProvider` (database di disk tidak bisa dibuka saat test).

**Alur pengingat:** `MonitoringController` memanggil `RuleEngine.evaluate` tiap evaluasi 10 detik `SessionEvaluator` (Mode AI) atau tiap detak `TimerService` saat 20-20-20 jatuh tempo (Mode Timer) → `ReminderController.show` (hanya satu sekaligus; ditolak saat Tunda/Mode Fokus, dan cooldown baru dimulai bila benar-benar tampil). Pop-up dipasang di `MaterialApp.builder` (`ReminderOverlay`). Opsi demo (simulasi mata lelah, simulasi terlalu dekat, percepat 20-20-20 ke 1 menit) hanya tampil dengan `DummyFaceAnalyzer`.

**Alur kredit:** `MonitoringController.startAi` → `CreditController.activateToday` → `CreditRepository.activateToday` (§8.2: hari sudah aktif → tidak memotong; kuota gratis bulan berjalan; kredit −1 di ledger; habis → `ActivationInsufficient`, Dashboard menawarkan beli kredit atau Mode Timer; error/offline → Mode Timer). Jangan menaruh logika kuota/saldo di controller UI; saldo selalu dari ledger server (§15.5).

**Alur statistik:** `StatsController` (dimuat saat halaman Statistik dibuka & saat pemantauan berhenti) → `MetricsRepository.dailySummary` untuk hari yang punya sesi (tidak membuat baris kosong) → `SyncService.syncPending()` (juga dipanggil setelah login/auto-login) mengirim `pendingSync()` ke `POST /stats/daily` lalu `markSynced` → tren dari `GET /stats`, atau dari `daily_summaries` lokal bila offline. Tombol "Isi data contoh 14 hari" hanya tampil di `kDebugMode`.

**Penanganan error login:** `AuthController` menangkap semua error (bukan hanya `AuthException`) dan memakai batas waktu `ApiConstants.authDeadline`, jadi spinner selalu berhenti. `ApiClient` memvalidasi `API_BASE_URL` (salah → `NetworkException` berisi petunjuk, bukan crash) dan membaca token dengan batas waktu `tokenStorageTimeout` (gagal/menggantung → request dikirim tanpa token). Jangan kembalikan pola `on AuthException` saja.

**Android jaringan:** `INTERNET` ada di manifest `main` (dibutuhkan release). `http://` (cleartext) hanya diizinkan untuk build debug & profile lewat `src/{debug,profile}/res/xml/network_security_config.xml`; release tetap HTTPS saja (KMN-01). Emulator → `http://10.0.2.2:8000/api`; HP fisik → `php artisan serve --host=0.0.0.0` + IP LAN laptop.

**Backend vs tiruan:** `ApiConstants.useRemoteApi` bawaan `true` → `ApiAuthRepository`, `ApiCreditRepository`, `ApiStatsRepository`, `ApiAiAdviceRepository`. Di bawah `flutter test` (env `FLUTTER_TEST`) atau `--dart-define=USE_REMOTE_API=false` → `Fake*Repository` (+ Gemini langsung khusus debug). Base URL bawaan `http://127.0.0.1:8000/api` (desktop) / `http://10.0.2.2:8000/api` (emulator Android); HP fisik/produksi → `--dart-define=API_BASE_URL=...`.

**Alur akun:** splash → `AuthController.restoreSession` (token → `GET /me`; 401 → token dihapus → Login; offline → profil tersimpan) → `goAfterSignIn` (privasi → kalibrasi → Dashboard). Persetujuan privasi per akun di `settings` (`privacy_accepted:<email>`). Hapus akun: `DELETE /me` → `LocalDataCleaner.wipeAll` (semua tabel lokal) → Login.

**Alur beli kredit:** `CreditController.buy` → `POST /orders` → `urlOpenerProvider` membuka `redirect_url` di browser → kartu "Menunggu pembayaran" → saat aplikasi aktif lagi / tombol "Muat ulang status" → `GET /orders/{code}` + muat ulang status & riwayat. Kredit hanya bertambah dari notifikasi Midtrans di server; klien tidak pernah menambah saldo sendiri.

**Pesan error:** pakai `friendlyErrorMessage(e)` (`core/network/api_exception.dart`) untuk menampilkan error API ke pengguna (401/402/403/404/422/429/5xx/offline); jangan tampilkan teks mentah Laravel.

## 5. Perintah penting

```bash
flutter pub get          # pasang dependensi
dart run build_runner build   # buat ulang app_database.g.dart setelah mengubah tabel
flutter analyze          # analisis statis
flutter test             # jalankan unit & widget test
flutter run -d windows   # jalankan aplikasi di Windows (backend: http://127.0.0.1:8000/api)
flutter run -d windows --dart-define=USE_REMOTE_API=false   # tanpa server (repository tiruan)

cd backend
composer install
php artisan migrate:fresh --seed   # MySQL lokal visionguard
php artisan serve                  # http://127.0.0.1:8000/api
php artisan test                   # feature test (SQLite in-memory)
./vendor/bin/pint --test           # gaya kode PHP
```

> Build Windows membutuhkan komponen Visual Studio **"C++ ATL for latest build tools"** (dipakai oleh `flutter_secure_storage_windows`).

## 6. Aturan

1. **Jangan upgrade versi major** dependensi apa pun (Flutter SDK, Riverpod, go_router, dll.) tanpa izin pengguna.
2. **`lib/cv_engine/` tidak boleh bergantung pada UI** — tidak meng-import `package:flutter/material.dart`, widget, atau modul `features/*/presentation`. UI hanya membaca state lewat Riverpod.
3. **Frame kamera tidak boleh disimpan atau dikirim ke mana pun** — tidak ke disk, log, cache, database lokal, Gemini, maupun jaringan. Frame berhenti di CV Engine. Database lokal hanya menyimpan angka; jangan menambah kolom BLOB/gambar.
4. **Konstanta CV** (ambang EAR, PERCLOS, jarak, bobot skor, dll.) **hanya** didefinisikan di `lib/core/constants/cv_constants.dart`; jangan hard-code di tempat lain.
5. **Setelah mengubah kode**, jalankan `flutter analyze` dan `flutter test` sampai **bersih** (tanpa error, warning, maupun test gagal). Bila mengubah `backend/`, jalankan juga `php artisan test` dan `./vendor/bin/pint --test`.
6. Patuhi juga panduan kepatuhan di `DOCS_SPEC.md` §15. Untuk Saran AI, patuhi §17: hanya angka ringkasan yang boleh dikirim.
7. **DILARANG** menjalankan `git commit`, `git push`, `git reset`, `git clean`, atau perintah git lain yang mengubah riwayat/remote. Commit dan push hanya dilakukan oleh pengguna. Jangan pernah menambahkan baris `Co-Authored-By`.
