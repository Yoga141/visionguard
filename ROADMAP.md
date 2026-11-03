# ROADMAP — VisionGuard menuju progress 100%

Panduan kerja untuk AI agent berikutnya (Claude Code, Antigravity, OpenCode, dll.).
Dokumen ini **tidak** menggantikan `DOCS_SPEC.md`. Jika ada yang bertentangan, `DOCS_SPEC.md` yang berlaku.

Terakhir diperbarui: 2 November 2026 · Basis: commit `3ba90c3` (progress 50%).

**Ringkasan tahap**

- [ ] **Tahap A**: Backend Laravel inti (`./backend`)
- [ ] **Tahap B**: Midtrans Sandbox, panel admin Filament, reset kata sandi via email
- [ ] **Tahap C**: Integrasi Flutter ke backend
- [ ] **Tahap D**: Deteksi wajah asli MediaPipe
- [ ] **Tahap E**: Latar belakang, Sesi Cek Mata, autostart, kamera bentrok, bantuan & FAQ
- [ ] **Tahap F**: Finalisasi dan serah terima

Urutan wajib A → B → C. Tahap D dan E tidak bergantung pada backend, jadi boleh dikerjakan lebih dulu **jika pengguna memintanya**. Tahap F selalu terakhir.

---

## 0. Aturan untuk semua agent

1. **Baca dulu** `AGENTS.md`, `DOCS_SPEC.md`, lalu dokumen ini. Untuk hal yang belum diatur `DOCS_SPEC.md`, atau yang masuk §16 (Keputusan Terbuka), **tanyakan pengguna dulu**.
2. **Satu tahap per sesi.** Jangan memulai tahap berikutnya di sesi yang sama kecuali pengguna memintanya.
3. **Jalankan verifikasi sampai bersih** sebelum menyatakan selesai:
   - Flutter: `flutter analyze` (0 issue) dan `flutter test` (semua lulus).
   - Backend: `php artisan test` (semua lulus) dan, bila dipasang, `./vendor/bin/pint --test`.
4. **Akhir tiap tahap:** centang tahap dan butir kriteria di dokumen ini, isi baris "Catatan sesi" (tanggal, ringkasan, keputusan baru), dan perbarui tabel status di `README.md` serta struktur di `AGENTS.md` §4 bila ada folder/berkas baru.
5. **DILARANG** `git commit`, `git push`, `git reset`, `git clean`, `git rebase`, `git checkout -- .`, atau perintah lain yang mengubah riwayat/remote. Jangan menambahkan baris `Co-Authored-By`. Commit dilakukan pengguna.
6. Aturan `AGENTS.md` §6 tetap berlaku: jangan upgrade versi major, `lib/cv_engine/` tanpa UI, frame kamera tidak pernah disimpan/dikirim, konstanta CV hanya di `cv_constants.dart`.
7. Rahasia (`MIDTRANS_SERVER_KEY`, `GEMINI_API_KEY`, kata sandi SMTP/DB) hanya di `.env` yang tidak di-commit. Sediakan `.env.example` tanpa nilai rahasia.
8. Menambah paket baru (Composer/pub) boleh bila memang dibutuhkan tahapnya. Sebutkan di ringkasan akhir sesi. Bila ada beberapa pilihan paket yang setara, tanyakan pengguna.

---

## 1. Status saat ini (progress 50%)

Diverifikasi terhadap kode di `lib/` dan `test/`. Folder `backend/` **belum ada**. Semua fitur yang butuh server memakai repository tiruan (`Fake*Repository`).
Legenda: ✅ selesai · 🟡 sebagian · ⏳ belum.

### AKN — Akun

| ID | Status | Bukti di kode | Yang kurang |
|---|---|---|---|
| AKN-01 | 🟡 | `login_page.dart` (form + validasi), `FakeAuthRepository`, `ApiAuthRepository` (`POST /auth/register`) | Server; menangani 422 dari server |
| AKN-02 | 🟡 | `auth_controller.dart`, `ApiAuthRepository` (`/auth/login`, `/auth/logout`), `token_storage.dart` | Server; auto-login dari token tersimpan; login admin (Filament); penahanan 5 menit setelah 5× gagal (KMN-02) |
| AKN-03 | ⏳ | Tombol "Lupa kata sandi?" hanya menampilkan info | Endpoint + email + UI |
| AKN-04 | 🟡 | Dialog konfirmasi di `settings_page.dart` | `DELETE /me`, hapus data lokal |

### KLB — Kalibrasi

| ID | Status | Bukti di kode |
|---|---|---|
| KLB-01 | ✅ | `privacy_onboarding_page.dart` (privasi + penafian medis, tolak → Mode Timer) |
| KLB-02 | ✅ | `calibration_controller.dart` (median EAR 10 dtk) |
| KLB-03 | ✅ | Focal length pada jarak acuan + opsi lewati (FOV 60°) |
| KLB-04 | ✅ | `calibration_repository.dart` per `camera_id` |

Catatan: kalibrasi baru teruji dengan `DummyFaceAnalyzer`. Uji ulang dengan wajah asli di Tahap D.

### PMT — Pemantauan

| ID | Status | Bukti di kode | Yang kurang |
|---|---|---|---|
| PMT-01 | 🟡 | `FakeCreditRepository.activateToday` (algoritma §8.2), `CreditController` | `POST /monitoring-days/activate` |
| PMT-02 | 🟡 | `blink_analyzer.dart` (EAR, kedip 100–400 ms, BR 60 dtk) | Landmark asli (MediaPipe) |
| PMT-03 | 🟡 | `distance_estimator.dart` (median iris 1 dtk) | Landmark asli |
| PMT-04 | 🟡 | `session_evaluator.dart`, `fatigue_scorer.dart` (int, tiap 10 dtk) | Landmark asli |
| PMT-05 | ✅ | `SessionEvaluator` (wajah hilang > 10 dtk → jeda) | — |
| PMT-06 | ⏳ | — | Tray Windows, foreground service Android |
| PMT-07 | ⏳ | — | Sesi Cek Mata 2 menit (S-07) |
| PMT-08 | 🟡 | Mode Timer saat offline/kredit habis/privasi ditolak | Kamera dipakai aplikasi lain → Mode Timer + coba ulang tiap 60 dtk |

### PNG — Pengingat (semua ✅)

`rule_engine.dart`, `timer_service.dart`, `break_verifier.dart`, `reminder_hold.dart`, `reminder_controller.dart`, `notification_service.dart`, `reminder_popup.dart`.
PNG-01 kedip · PNG-02 jarak · PNG-03 istirahat · PNG-04 20-20-20 · PNG-05 verifikasi berpaling · PNG-06 Tunda & Mode Fokus (dari Dashboard; dari tray menyusul di Tahap E) · PNG-07 cooldown.

### STK — Statistik

| ID | Status | Bukti di kode | Yang kurang |
|---|---|---|---|
| STK-01 | ✅ | `metrics_repository.dart` (`dailySummary`), `statistics_page.dart` tab Hari Ini | — |
| STK-02 | ✅ | `fl_chart` 7/30 hari, "data belum cukup" < 2 hari | — |
| STK-03 | 🟡 | `daily_summaries.synced`, `StatsController`, `FakeStatsRepository` | `POST /stats/daily`, `GET /stats` |

### KRD — Kredit & Pembayaran

| ID | Status | Bukti di kode | Yang kurang |
|---|---|---|---|
| KRD-01 | 🟡 | `credits_page.dart` (S-09), kartu status di Dashboard | `GET /credits/status` |
| KRD-02 | ⏳ | Daftar paket + tombol Beli (dialog "setelah backend siap") | `POST /orders` + halaman Midtrans |
| KRD-03 | ⏳ | — | Notifikasi Midtrans di server |
| KRD-04 | 🟡 | UI riwayat order & ledger (data tiruan) | `GET /orders`, `GET /credits/history` |

### PGT — Pengaturan

| ID | Status | Bukti di kode |
|---|---|---|
| PGT-01 | ✅ | `settings_controller.dart` (sensitivitas τ 0,65/0,70/0,75, jenis pengingat, interval 10–60 mnt) |
| PGT-02 | ⏳ | Tampil "segera hadir" (`coming_soon.dart`) |

### ADM — Admin (semua ⏳)

ADM-01, ADM-02, ADM-03 belum ada. Akan dibangun dengan Filament di Tahap B.

### Lain-lain

- **Saran AI (§17):** ✅ di klien (`ai_assistant/`). Mode pengembangan memanggil Gemini langsung. `ApiAiAdviceRepository` (`POST /ai/advice`) sudah ada tetapi belum aktif.
- **Infrastruktur klien siap pakai:** `ApiClient` (Dio + interceptor token), `ApiException`, `TokenStorage`, flag `ApiConstants.useRemoteApi`, SQLite drift (6 tabel §12.3).
- **Test yang ada:** `cv_engine`, `network`, `ai_advice`, `ai_advice_card`, `database`, `local_storage_flow`, `settings`, `reminders`, `stats`, `credits`, `widget`. Coverage belum pernah diukur.

---

## 2. Pekerjaan tersisa

### Tahap A — Backend Laravel inti

**Tujuan:** REST API Laravel + Sanctum + MySQL di `./backend` yang memenuhi kontrak §11 dan skema §12.2, belum termasuk pembayaran.

**ID kebutuhan:** AKN-01, AKN-02 (sisi server), AKN-04, PMT-01, STK-03, KRD-01, KRD-04, KMN-02, KMN-03, PRV-02, Saran AI §17.4.

**Keputusan yang harus ditanyakan ke pengguna sebelum mulai:**
- Path final endpoint usulan §11.2 (`/auth/logout`, `/credit-packages`, `/orders`, `/credits/history`, `/payments/midtrans/notification`, `/me`) dan §17.4 (`/ai/advice`), termasuk batas pemakaian (429) Saran AI.
- Versi Laravel (disarankan Laravel 11 atau 12, PHP 8.2+) dan pilihan PHPUnit atau Pest.
- Nama kolom sandi: SDD memakai `password_hash`, sedangkan bawaan Laravel `password`. Bila memakai `password_hash`, override `getAuthPassword()` di model `User`.

**File/folder yang dibuat:**
- `backend/` — proyek Laravel baru (`composer create-project laravel/laravel backend`), `php artisan install:api` untuk Sanctum.
- `backend/.env.example` — `DB_DATABASE=visionguard`, `GEMINI_API_KEY=`, tanpa rahasia.
- `backend/database/migrations/` — 7 tabel §12.2: `users` (+`role`, `timezone`), `devices`, `credit_packages`, `orders`, `credit_ledger`, `monitoring_days`, `daily_stats`, lengkap dengan constraint `UNIQUE(email)`, `UNIQUE(order_code)`, `UNIQUE(credit_ledger.order_id)`, `UNIQUE(user_id, day)`, `UNIQUE(user_id, device_id, day)`. Tabel bawaan Laravel (`personal_access_tokens`, `password_reset_tokens`, `cache`, `jobs`) boleh tetap ada.
- `backend/app/Models/` — `User` (`creditBalance()` = SUM delta, `freeQuotaRemaining()` per bulan berjalan menurut `timezone`), `Device`, `CreditPackage`, `Order` (`markSettled()` disiapkan untuk Tahap B), `CreditLedger` (tolak update/delete lewat event model → append-only), `MonitoringDay`, `DailyStat`.
- `backend/app/Http/Controllers/Api/` — `AuthController`, `AccountController`, `MonitoringDayController`, `CreditController`, `CreditPackageController`, `OrderController` (hanya `index` di tahap ini), `StatsController`, `AiAdviceController`.
- `backend/app/Services/MonitoringDayService.php` — algoritma §8.2 dalam satu transaksi DB (`lockForUpdate` pada user agar aktivasi ganda bersamaan tidak memotong dua kali).
- `backend/app/Services/GeminiAdviceService.php` — memanggil Gemini via HTTP, hanya angka §17.2, tanpa menyimpan prompt/respons.
- `backend/app/Http/Requests/` — validasi tiap endpoint.
- `backend/routes/api.php` — semua rute di bawah prefix `/api`, `auth:sanctum` kecuali register/login/forgot/reset/notifikasi Midtrans.
- `backend/database/seeders/` — `AdminSeeder` (1 admin), `CreditPackageSeeder` (mis. 3 paket aktif + 1 nonaktif), `DemoUserSeeder` (`demo@visionguard.id` / `password123`, sama dengan akun demo klien).
- `backend/tests/Feature/` — test per endpoint (lihat kriteria).
- `API_CONTRACT.md` di root — skema JSON request/response tiap endpoint (menutup §16 #8 dan #9). Klien Tahap C mengikuti dokumen ini.

**Aturan penting:**
- Register → 201 + token; email terpakai → 422. Login salah → 401; 5× gagal → tahan 5 menit (`RateLimiter` per email+IP) → 429. Login sukses mencatat `devices` (`platform`, `device_name`, `last_seen_at`) dan mengembalikan `device_id`.
- `POST /monitoring-days/activate` → 200 + `{free_quota_remaining, credit_balance, today_active, source}`; kredit kurang → **402**.
- `DELETE /me` + kata sandi → salah 403; benar → hapus akun, `devices`, `daily_stats`; order dianonimkan (`user_id = NULL`); semua token dicabut. Nasib `monitoring_days` dan `credit_ledger` tidak disebut §8.7 (ledger append-only, tetapi PDP meminta data pribadi dihapus), jadi **tanyakan pengguna** apakah dihapus atau dianonimkan.
- Saldo **tidak pernah** dikirim dari klien. Tidak ada kolom gambar di tabel mana pun.

**Kriteria selesai:**
- [ ] `php artisan migrate:fresh --seed` sukses pada MySQL lokal `visionguard`.
- [ ] Semua endpoint §11.1 (kecuali pembayaran & reset sandi) dan §11.2 yang disetujui berjalan, plus `POST /ai/advice`.
- [ ] Feature test mencakup minimal: register 201/422, login 200/401/429, logout mencabut token, aktivasi (sudah aktif → tidak memotong; kuota gratis; potong kredit −1 dengan `monitoring_day_id`; 402; ganti bulan mereset kuota; zona waktu akun menentukan tanggal), `GET /credits/status`, upsert `POST /stats/daily` (kirim dua kali → satu baris), `GET /stats?days=7|30`, `DELETE /me` 200/403 + anonimisasi order, ledger tidak bisa di-update/delete, `POST /ai/advice` 200/422/401 (Gemini di-mock dengan `Http::fake`).
- [ ] `API_CONTRACT.md` lengkap dan disetujui pengguna.

**Cara verifikasi:**
```bash
cd backend
composer install
cp .env.example .env && php artisan key:generate   # isi DB_* untuk MySQL lokal
php artisan migrate:fresh --seed
php artisan test
php artisan serve        # atau situs Herd: http://backend.test
curl -X POST http://127.0.0.1:8000/api/auth/login -H "Accept: application/json" \
     -d "email=demo@visionguard.id&password=password123&platform=windows&device_name=dev"
```
Klien Flutter tidak diubah di tahap ini, jadi `flutter analyze` dan `flutter test` harus tetap bersih.

---

### Tahap B — Midtrans Sandbox, panel admin Filament, reset kata sandi

**Tujuan:** pembelian kredit end-to-end di sisi server, panel admin, dan reset sandi lewat email.

**ID kebutuhan:** KRD-02, KRD-03 (server), AKN-02 (admin), AKN-03 (server), ADM-01, ADM-02, ADM-03, KMN-03.

**File/folder yang dibuat atau diubah:**
- `backend/composer.json` — `midtrans/midtrans-php`, `filament/filament` (versi yang cocok dengan Laravel terpasang).
- `backend/config/services.php` + `.env.example` — `MIDTRANS_SERVER_KEY`, `MIDTRANS_CLIENT_KEY`, `MIDTRANS_IS_PRODUCTION=false`.
- `backend/app/Services/MidtransService.php` — membuat transaksi Snap, mengembalikan `snap_token` dan `redirect_url`.
- `OrderController@store` — `POST /orders {package_id}`: hanya paket aktif; buat `order_code` unik + `amount_idr` dari harga server; status `pending`; balas `{order_code, snap_token, redirect_url}`.
- `backend/app/Http/Controllers/Api/PaymentNotificationController.php` — `POST /payments/midtrans/notification` (path final sesuai Tahap A):
  - Verifikasi `signature_key = sha512(order_id + status_code + gross_amount + server_key)`; tidak valid → tolak + `Log::warning`.
  - `settlement` (dan `capture` dengan `fraud_status=accept`, **tanyakan pengguna**) → dalam satu transaksi DB: `Order::markSettled()` (`paid_at`, `payment_type`) + insert ledger `purchase` dengan `order_id`. Notifikasi berulang tidak menambah kredit (dijamin `UNIQUE(order_id)` + cek status).
  - `expire` / `cancel` / `deny` → update status, tanpa kredit.
  - Selalu 200 untuk notifikasi valid. Pastikan rute ini dikecualikan dari CSRF dan tidak memakai `auth:sanctum`.
- `backend/app/Filament/Resources/` — `CreditPackageResource` (A-01: tambah/ubah/nonaktifkan; tombol hapus disembunyikan bila paket pernah dibeli), `OrderResource` (A-02: filter status & tanggal, hanya baca), `UserResource` (A-03: daftar pengguna + saldo, aksi "Sesuaikan kredit" dengan `delta` & `note` wajib; saldo akhir negatif → tolak).
- `backend/app/Services/CreditAdjustmentService.php` — logika §8.5, dipakai oleh aksi Filament (`CreditAdjustmentController` di SDD).
- `User::canAccessPanel()` — hanya `role = admin`.
- `AuthController@forgotPassword` / `resetPassword` — Password broker Laravel, token 60 menit (`config/auth.php` `expire = 60`); email tak terdaftar → 404; token salah/kedaluwarsa → 422; `password_confirmation` wajib.
- Email reset: `MAIL_MAILER=log` untuk pengembangan, SMTP (mis. Mailtrap/Gmail) untuk uji nyata. **Tanyakan pengguna** format tautan reset: halaman web Laravel sederhana atau deep link ke aplikasi (memengaruhi Tahap C).

**Kriteria selesai:**
- [ ] Feature test: `POST /orders` (paket nonaktif → 422), notifikasi signature salah → ditolak & tidak ada ledger, `settlement` → +kredit sekali, notifikasi yang sama dikirim 2× → kredit tetap sekali, `expire`/`cancel`/`deny` → tanpa kredit, penyesuaian admin (alasan kosong ditolak, saldo negatif ditolak), forgot 404/200, reset 200/422, `Mail::fake` / `Notification::fake` memastikan email terkirim.
- [ ] Panel `/admin` dapat dibuka akun admin seeder, ditolak untuk akun `user`.
- [ ] Uji manual Sandbox: buat order → bayar di simulator Midtrans → notifikasi masuk (via tunnel) → saldo bertambah.

**Cara verifikasi:**
```bash
cd backend && php artisan test
php artisan serve
# Tunnel publik untuk notifikasi Midtrans, mis.:
cloudflared tunnel --url http://127.0.0.1:8000     # atau: ngrok http 8000
# Isi Payment Notification URL di dashboard Midtrans Sandbox:
#   https://<tunnel>/api/payments/midtrans/notification
# Bayar memakai https://simulator.sandbox.midtrans.com, lalu cek saldo:
curl -H "Authorization: Bearer <token>" -H "Accept: application/json" http://127.0.0.1:8000/api/credits/status
```
Buka `http://127.0.0.1:8000/admin`, login sebagai admin, coba A-01..A-03.

---

### Tahap C — Integrasi Flutter ke backend

**Tujuan:** aplikasi memakai backend asli bila `USE_REMOTE_API=true`; repository tiruan tetap dipakai untuk test dan mode tanpa server.

**ID kebutuhan:** AKN-01..04, PMT-01, PMT-08 (offline), STK-03, KRD-01..04, Saran AI §17.3 (versi final), KMN-01, PRV-02.

**File/folder yang dibuat atau diubah:**
- `lib/features/auth/data/auth_repository.dart` — tambah kontrak `restoreSession()` (auto-login dari token tersimpan), `forgotPassword(email)`, `resetPassword(...)` (bila tautan berupa deep link), `deleteAccount(password)`. Implementasikan di `FakeAuthRepository` dan `ApiAuthRepository`.
- `lib/features/auth/application/auth_controller.dart` + `lib/app/router.dart` — saat start: token ada → `GET /me` → Dashboard (atau Kalibrasi bila belum ada kalibrasi); 401 → hapus token → Login. Tangani 422 (email terpakai), 401, 429 (tahan 5 menit) dengan pesan yang jelas.
- `lib/features/auth/presentation/login_page.dart` — form "Lupa kata sandi" yang sungguhan.
- `lib/features/settings/presentation/settings_page.dart` — hapus akun: input sandi → `DELETE /me` → 403 tampilkan pesan → 200 hapus semua tabel lokal (kalibrasi, sesi, metrik, alerts, ringkasan, settings) + token → Login.
- `lib/features/credits/data/api_credit_repository.dart` — implementasi `CreditRepository` (`status`, `activateToday` termasuk 402 → `ActivationInsufficient`, `packages`, `orders`, `ledger`) + metode baru `createOrder(packageId)`.
- `lib/features/credits/presentation/credits_page.dart` — Beli → `POST /orders` → buka `redirect_url` Snap (tambah `url_launcher`; WebView opsional, **tanyakan pengguna**) → saat kembali ke aplikasi/tombol "Muat ulang status" → `GET /credits/status` + `GET /orders`. Order pending tampil "Menunggu pembayaran".
- `lib/features/stats/data/api_stats_repository.dart` — `POST /stats/daily` (sertakan `device_id`), `GET /stats?days=`.
- Provider `authRepositoryProvider`, `creditRepositoryProvider`, `statsRepositoryProvider`, `aiAdviceRepositoryProvider` — pilih implementasi API bila `ApiConstants.useRemoteApi`.
- `pubspec.yaml` — bila `useRemoteApi`, jangan bergantung pada `.env` (siapkan langkah menghapus `.env` dari asset untuk build rilis, §17.5).
- `test/` — test baru untuk repository API memakai Dio dengan adapter tiruan (pola sudah ada di `network_test.dart`), test auto-login, hapus akun, 402.

**Kriteria selesai:**
- [ ] Dengan backend Tahap A–B berjalan: daftar → onboarding → kalibrasi → mulai Mode AI memotong kuota/kredit di server; tutup & buka aplikasi → langsung masuk (auto-login).
- [ ] Beli paket di Sandbox → saldo di S-09 bertambah setelah muat ulang.
- [ ] Statistik tersinkron (`daily_summaries.synced = 1`, baris muncul di `daily_stats`); offline → data lokal dan dikirim ulang saat online.
- [ ] Saran AI lewat `POST /ai/advice`; gagal → saran statis.
- [ ] Lupa sandi dan hapus akun berjalan sesuai §8.7.
- [ ] Tanpa `--dart-define`, aplikasi tetap berjalan dengan repository tiruan; semua test lama tetap lulus.

**Cara verifikasi:**
```bash
flutter analyze
flutter test
# backend jalan di http://127.0.0.1:8000 (emulator Android: http://10.0.2.2:8000)
flutter run -d windows --dart-define=USE_REMOTE_API=true --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
Catatan: build pengembangan ke `http://` lokal butuh izin cleartext Android (`network_security_config` khusus debug). Rilis wajib HTTPS (KMN-01).

---

### Tahap D — Deteksi wajah asli (MediaPipe)

**Tujuan:** mengganti `DummyFaceAnalyzer` dengan `MediaPipeFaceAnalyzer` yang menghasilkan 478 landmark + yaw dari frame kamera, tanpa mengubah `BlinkAnalyzer`, `DistanceEstimator`, `FatigueScorer`, dan `SessionEvaluator`.

**ID kebutuhan:** PMT-02, PMT-03, PMT-04, KLB-02, KLB-03 (dengan data asli), PNG-05 (yaw asli), KNR-01, AKR-01, AKR-02, PRV-01.

**Keputusan yang harus ditanyakan ke pengguna sebelum mulai:** jalur implementasi. Spesifikasi (§4.2) menyebut MediaPipe Face Landmarker via `tflite_flutter` (sudah dikomentari di `pubspec.yaml`). Alternatif lain (plugin platform MediaPipe Tasks, atau ML Kit yang hanya 468 titik tanpa iris) menyimpang dari spesifikasi.

**File/folder yang dibuat atau diubah:**
- `pubspec.yaml` — aktifkan `tflite_flutter` (versi minor yang kompatibel, tanpa upgrade major dependensi lain) + asset model (`assets/models/face_detection_short_range.tflite`, `face_landmark_with_attention.tflite` atau `face_landmarker` yang setara; catat sumber & lisensi model di README).
- `lib/cv_engine/mediapipe_face_analyzer.dart` — `implements FaceAnalyzer`: konversi frame kamera (YUV420 Android / BGRA Windows) ke tensor di memori, deteksi wajah → crop → landmark 478 titik → yaw dari landmark. Frame **tidak** ditulis ke disk/log. Inferensi di isolate terpisah agar UI tidak tersendat.
- `lib/cv_engine/cv_providers.dart` — pilih `MediaPipeFaceAnalyzer`; bila model gagal dimuat atau platform tidak didukung → **fallback ke `DummyFaceAnalyzer`** dengan label jelas di Dashboard (opsi demo tetap hanya tampil untuk dummy).
- `lib/core/constants/cv_constants.dart` — verifikasi ulang indeks landmark mata & iris (§9.2 catatan) dan konstanta inferensi (ukuran input, fps target 15/10).
- `lib/cv_engine/camera_source.dart` — format gambar & resolusi 640×480, pembatasan fps.
- `test/cv_engine_test.dart` — test `MediaPipeFaceAnalyzer` dengan tensor/landmark tiruan (pemetaan indeks, yaw, wajah tidak terdeteksi → `isValid=false`) dan test fallback.

**Kriteria selesai:**
- [ ] **Android (wajib):** kedipan nyata terdeteksi, jarak tampil wajar setelah kalibrasi (uji 30/50/80 cm dengan penggaris, target ±5 cm), menoleh > 30° → frame tidak valid, ≥ 10 fps.
- [ ] **Windows (best effort):** sama seperti Android dengan target ≥ 15 fps; bila belum berhasil, aplikasi otomatis memakai dummy dan alasannya dicatat di README/ROADMAP.
- [ ] Tidak ada frame yang disimpan/dikirim (cek manual: tidak ada `File(...).write`, `print(frame)`, atau upload di jalur kamera).
- [ ] `lib/cv_engine/` tetap tanpa import UI.

**Cara verifikasi:**
```bash
flutter analyze
flutter test
flutter run -d <id-hp-android>      # lihat: flutter devices
flutter run -d windows
```
Catat fps, hasil uji jarak, dan jumlah kedipan terdeteksi vs dihitung manual (1 menit) di "Catatan sesi".

---

### Tahap E — Latar belakang, Sesi Cek Mata, autostart, kamera bentrok, bantuan

**Tujuan:** melengkapi perilaku platform dan dokumentasi pengguna di dalam aplikasi.

**ID kebutuhan:** PMT-06, PMT-07, PMT-08 (kamera dipakai aplikasi lain), PGT-02, PNG-06 (Mode Fokus dari tray), S-07, S-11, KDL-02, KNR-02, §7.5 (bantuan & FAQ).

**File/folder yang dibuat atau diubah** (nama paket adalah saran, konfirmasikan ke pengguna):
- **System tray Windows (S-11):** `lib/features/background/` (atau `lib/app/tray/`) memakai `tray_manager` + `window_manager`. Menu: status, Jeda/Lanjut, Mode Fokus (30/60/90/120), buka Dashboard, Logout, Keluar. Menutup jendela → sembunyi ke tray, kamera tetap jalan, indikator kamera aktif tetap terlihat (ikon tray berubah).
- **Foreground service Android:** `flutter_foreground_task` (atau setara), izin `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`, `CAMERA` di `android/app/src/main/AndroidManifest.xml`; notifikasi permanen; **berhenti saat layar mati** (KDL-02, §16 #11).
- **Sesi Cek Mata (PMT-07, S-07, UC-11):** `lib/features/eye_check/` (data/application/presentation). Hanya mobile. Cek status hari → belum aktif → arahkan aktivasi; teks bacaan + hitung mundur 120 dtk; keluar < 2 mnt → batal & tidak disimpan; hasil skor + saran (boleh memakai kartu Saran AI). Simpan `sessions.mode = 'check'`. Durasi 120 dtk sebagai konstanta di `cv_constants.dart`.
- **Kamera dipakai aplikasi lain (PMT-08):** di `monitoring_controller.dart` tangkap kegagalan `CameraSource.start()` (mis. `CameraException` "in use") → beralih ke Mode Timer + pesan, coba ulang tiap 60 dtk (konstanta di `cv_constants.dart`), kembali ke Mode AI saat kamera tersedia tanpa memotong kredit lagi.
- **Autostart (PGT-02):** `launch_at_startup` (Windows), toggle di `settings_page.dart` menggantikan "segera hadir"; simpan di `settings`.
- **Bantuan & FAQ (§7.5):** `lib/features/help/` — halaman bantuan + FAQ (kenapa kamera tidak aktif, kenapa jarak tidak akurat, cara hitung kuota gratis, arti BR/jarak/skor), ikon bantuan di AppBar tiap layar utama. Teks statis, tanpa jaringan.
- `test/` — test Sesi Cek Mata (batal < 2 mnt, hasil tersimpan), test retry kamera 60 dtk dengan jam tiruan, widget test halaman bantuan.

**Kriteria selesai:**
- [ ] Windows: tutup jendela → pemantauan lanjut di tray; menu tray berfungsi; autostart aktif setelah login ulang Windows.
- [ ] Android: pemantauan lanjut saat aplikasi di latar belakang dengan notifikasi permanen; berhenti saat layar mati.
- [ ] Buka kamera di aplikasi lain (mis. Zoom/Kamera Windows) → VisionGuard pindah ke Mode Timer, lalu kembali ke Mode AI ≤ 60 dtk setelah kamera dilepas.
- [ ] Sesi Cek Mata berjalan di HP Android sesuai UC-11.
- [ ] Ikon bantuan ada di Dashboard, Statistik, Kredit, Pengaturan, Kalibrasi.

**Cara verifikasi:**
```bash
flutter analyze
flutter test
flutter run -d windows
flutter run -d <id-hp-android>
```
Ukur CPU/RAM Windows saat di tray (Task Manager, target ≤ 15% / ≤ 300 MB, KNR-02) dan catat hasilnya.

---

### Tahap F — Finalisasi

**Tujuan:** memastikan semua kebutuhan terpenuhi, kode rapi, dokumen mutakhir, dan siap diserahkan.

**ID kebutuhan:** semua; khususnya PML-01 (coverage ≥ 70%), PRV-01..03, KSL-01, USB-01, USB-02.

**File/folder yang dibuat atau diubah:**
- `README.md` — tabel status semua ID (termasuk ADM) diperbarui, cara menjalankan backend + klien.
- `DOCS_SPEC.md` §16 — tandai butir yang sudah diputuskan/diterapkan (#8, #9, #10, #11, keputusan baru dari Tahap A–E). §17 — perbarui status `POST /ai/advice` dan risiko key (setelah `.env` keluar dari asset rilis). **Minta persetujuan pengguna** sebelum memindahkan isi §17 ke bagian utama.
- `AGENTS.md` §3–§4 — stack & struktur folder terbaru (backend, fitur baru).
- `HANDOFF.md` di root — ringkasan arsitektur, cara setup dari nol, akun demo/admin, variabel `.env`, hasil uji (fps, akurasi jarak/kedip, CPU/RAM), batasan yang diketahui, dan daftar pekerjaan lanjutan (macOS/iOS, distribusi §4.5, deploy VPS §4.1).
- `test/` dan `backend/tests/` — tambah test sampai coverage tercapai.
- Bersihkan: kode mati, TODO kedaluwarsa, `print`/`debugPrint` yang tidak perlu, opsi debug tetap di balik `kDebugMode`.

**Kriteria selesai:**
- [ ] Audit: tiap ID di DOCS_SPEC §5 punya status + bukti (berkas/test) di README. Yang tidak dikerjakan (mis. macOS/iOS) dicatat beserta alasannya.
- [ ] Coverage ≥ 70% untuk `lib/cv_engine/` dan aturan kredit (`lib/features/credits/` + `backend` `MonitoringDayService`, `CreditAdjustmentService`, notifikasi pembayaran).
- [ ] Pencarian privasi bersih: tidak ada penulisan frame/gambar ke disk/jaringan; tidak ada kolom BLOB/gambar.
- [ ] `flutter analyze`, `flutter test`, `php artisan test` semuanya bersih.
- [ ] `HANDOFF.md` ada dan semua tahap di ROADMAP tercentang.

**Cara verifikasi:**
```bash
flutter analyze
flutter test --coverage
# Ringkas lcov (mis. dengan genhtml atau skrip kecil) untuk lib/cv_engine/ dan lib/features/credits/
cd backend && php artisan test --coverage     # butuh Xdebug atau PCOV
```
```bash
# Pencarian privasi (dari root)
grep -rnE "writeAsBytes|File\(.*\)\.write|toImage|Blob|MultipartFile" lib backend/app
```

---

## 3. Prasyarat lingkungan

| Kebutuhan | Dipakai di | Catatan |
|---|---|---|
| **Flutter SDK** (Dart `^3.5.0`) | Semua tahap klien | `flutter doctor` tanpa error untuk Windows & Android |
| **Visual Studio 2022** + workload "Desktop development with C++" + komponen **"C++ ATL for latest build tools"** | Build Windows | Dibutuhkan `flutter_secure_storage_windows` |
| **Laravel Herd** (PHP 8.2+, Composer) | Tahap A, B | Windows: Herd menyediakan `php` dan `composer` di PATH. Untuk coverage backend pasang PCOV/Xdebug |
| **MySQL 8 lokal**, database **`visionguard`** | Tahap A, B, C | Mis. Herd Pro, MySQL Installer, atau Laragon. `CREATE DATABASE visionguard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;` |
| **Akun Midtrans Sandbox** | Tahap B, C | Ambil Server Key & Client Key dari dashboard Sandbox; butuh tunnel publik (`cloudflared`/`ngrok`) untuk Payment Notification URL |
| **SMTP** (Mailtrap/Gmail) | Tahap B | Opsional; `MAIL_MAILER=log` cukup untuk test |
| **Gemini API key** | Tahap A (server), dev klien | Disimpan di `backend/.env` untuk versi final |
| **HP Android** (Android 8.0+, RAM ≥ 3 GB) + USB debugging | Tahap C, D, E | Wajib untuk uji kamera, foreground service, Sesi Cek Mata |
| **Webcam** Windows | Tahap D, E | ≥ 640×480 @ 15 fps |

---

## 4. Catatan sesi

Isi satu baris setiap akhir sesi (terbaru di bawah).

| Tanggal | Tahap | Ringkasan | Keputusan baru / pertanyaan terbuka |
|---|---|---|---|
| 2026-11-02 | — | ROADMAP.md dibuat dari audit kode commit `3ba90c3` | — |
