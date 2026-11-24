# VisionGuard

Aplikasi Flutter berbasis *computer vision* untuk deteksi dini dan pencegahan kelelahan mata digital melalui analisis kedipan dan jarak pandang.

Mayoga Finanda (11241044) — Informatika. Dokumen acuan: SRS & SDD VisionGuard v1.0.

## Status: audit Tahap F (23 Nov 2026)

Legenda: ✅ selesai (kode + test otomatis) · 🟡 sebagian (kode ada, uji manual/perangkat atau sebagian
fitur belum) · ⏳ belum. Backend Laravel di `backend/` (lihat `backend/README.md`, `API_CONTRACT.md`);
aplikasi memakainya secara bawaan. Detail tahap: `ROADMAP.md`. Serah terima: `HANDOFF.md`.

Verifikasi terakhir: `flutter analyze` 0 issue · `flutter test` 217 lulus · `php artisan test` 91 lulus ·
Pint bersih · `flutter build apk --debug` berhasil. Coverage: `lib/cv_engine/` 77,5 %,
`lib/features/credits/` 88,7 % (PML-01); coverage backend tidak terukur (PHP tanpa Xdebug/PCOV).

### Kebutuhan fungsional (DOCS_SPEC §5)

| ID | Status | Lokasi kode | Catatan |
|---|---|---|---|
| AKN-01 | ✅ | `features/auth/` (`login_page`, `api_auth_repository`), `backend` `AuthController` | 422 email terpakai per kolom; test `auth_controller_test`, `AuthTest` |
| AKN-02 | ✅ | `auth_controller`, `token_storage`, `splash_page`; `backend` Sanctum, `LoginThrottle`; Filament `/admin` | Auto-login `GET /me`, penahanan 5× gagal → 5 mnt |
| AKN-03 | ✅ | `forgot_password_page`; `backend` `PasswordResetService`, halaman `/reset-password/{token}` | Bawaan `MAIL_MAILER=log`; kirim lewat SMTP asli belum diuji |
| AKN-04 | ✅ | `settings_page` (hapus akun), `local_data_cleaner`; `backend` `AccountService` | `DELETE /me` + hapus semua tabel lokal; ledger dianonimkan (§16 #19) |
| KLB-01 | ✅ | `features/onboarding/privacy_onboarding_page.dart` | Privasi + penafian medis, tolak → Mode Timer |
| KLB-02 | 🟡 | `calibration_controller.dart` | Median EAR 10 dtk teruji dengan data tiruan; belum dengan wajah asli |
| KLB-03 | 🟡 | `calibration_controller`, `distance_estimator` | Focal pada 50/30 cm + lewati (FOV 60°); akurasi dengan wajah asli belum diuji |
| KLB-04 | ✅ | `calibration_repository` (`camera_id`) | Kamera diganti → minta kalibrasi ulang |
| PMT-01 | ✅ | `credit_controller`, `api_credit_repository`; `backend` `MonitoringDayService` | §8.2 di server (lock baris); 402 → beli / Mode Timer |
| PMT-02 | 🟡 | `cv_engine/mediapipe_face_analyzer.dart`, `blink_analyzer.dart` | MediaPipe di Android/iOS, Windows mode simulasi; belum diuji di HP asli |
| PMT-03 | 🟡 | `distance_estimator.dart` (median iris 1 dtk) | Uji penggaris 30/50/80 cm belum |
| PMT-04 | 🟡 | `session_evaluator.dart`, `fatigue_scorer.dart` | Logika ✅ (skor tiap 10 dtk, int; pengingat dievaluasi tiap 1 dtk); menunggu uji wajah asli |
| PMT-05 | ✅ | `session_evaluator.dart` | Wajah hilang > 10 dtk → dijeda |
| PMT-06 | 🟡 | `features/background/` (`desktop_tray`, `foreground_service`, `background_coordinator`) | Tray Windows & foreground service Android ada; kamera Android berhenti saat app tak terlihat (§16 #32); belum diuji manual |
| PMT-07 | 🟡 | `features/eye_check/` | Alur UC-11 + simpan `mode='check'` teruji otomatis; belum diuji di HP |
| PMT-08 | ✅ | `monitoring_controller` (`_fallbackToTimerForCamera`, `retryCameraNow`), `camera_source` (`CameraFailure`) | Offline & hari belum aktif → Timer; kamera dipakai app lain → Timer + coba lagi 60 dtk |
| PNG-01 | ✅ | `reminders/application/rule_engine.dart` | BR < 10 selama 3 mnt, cooldown 10 mnt |
| PNG-02 | ✅ | `rule_engine.dart` | < 50/30 cm selama 10 dtk, cooldown 5 mnt |
| PNG-03 | ✅ | `rule_engine.dart` | Skor ≥ 60, cooldown 20 mnt |
| PNG-04 | ✅ | `timer_service.dart`, `reminder_controller.dart` | 20-20-20 + hitung mundur 20 dtk, Mode AI & Timer |
| PNG-05 | ✅ | `break_verifier.dart` | ≥ 15/20 dtk berpaling; yaw asli dari MediaPipe belum diuji di perangkat |
| PNG-06 | ✅ | `reminder_hold.dart`, Dashboard, menu tray | Tunda 15/30/60, Mode Fokus 30–120 (juga dari tray) |
| PNG-07 | ✅ | `rule_engine.dart` | Cooldown per jenis, dimulai saat tampil |
| STK-01 | ✅ | `metrics_repository.dailySummary`, `statistics_page` | Durasi, rata-rata BR/jarak/skor, pengingat, istirahat |
| STK-02 | ✅ | `statistics_page` (`fl_chart`) | 7/30 hari, "data belum cukup" < 2 hari |
| STK-03 | ✅ | `stats/application/sync_service.dart`; `backend` `StatsService` | Batch `POST /stats/daily`, offline → lokal |
| KRD-01 | ✅ | `credits_page`, `GET /credits/status` | Saldo dari ledger server |
| KRD-02 | 🟡 | `credit_controller.buy`; `backend` `OrderService`, `MidtransGateway` | Teruji otomatis & mode simulasi; transaksi Sandbox asli belum diuji manual |
| KRD-03 | 🟡 | `backend` `PaymentNotificationService` | Signature SHA-512 + idempoten teruji otomatis; notifikasi Sandbox asli belum |
| KRD-04 | ✅ | `credits_page`, `GET /credits/history` | Order + ledger |
| PGT-01 | ✅ | `settings_controller`, `settings_page` | τ 0,65/0,70/0,75; interval 10–60 mnt; jenis pengingat |
| PGT-02 | 🟡 | `background/data/autostart_service.dart`, `autostart_controller` | Windows (`HKCU\…\Run`); macOS belum; belum diuji login ulang |
| ADM-01 | ✅ | `backend/app/Filament/Resources/CreditPackages` | Paket pernah dibeli tidak bisa dihapus |
| ADM-02 | ✅ | Filament `Orders` (baca saja), `Users` | Filter status & tanggal |
| ADM-03 | ✅ | Filament `Users` → "Sesuaikan kredit", `CreditAdjustmentService` | Alasan wajib, saldo akhir ≥ 0 |
| SAI-01 | ✅ | `features/ai_assistant/` (`ai_advice_card`, `api_ai_advice_repository`); `backend` `GeminiAdviceService` | Dashboard, Statistik, hasil Sesi Cek Mata; hanya angka §8.9 |
| SAI-02 | ✅ | `ai_advice_repository.dart` (saran statis) | Error/offline/429/503 → saran statis |
| SAI-03 | ✅ | `backend` throttle `ai-advice`, `config/visionguard.php` | 10/jam/pengguna, gratis |

### Kebutuhan non-fungsional (DOCS_SPEC §6)

| ID | Status | Lokasi / bukti | Catatan |
|---|---|---|---|
| KNR-01 | 🟡 | `camera_source.dart` (throttle 15/10 fps), `IsolateInterpreter` | fps nyata belum diukur |
| KNR-02 | ⏳ | — | CPU/RAM di tray belum diukur |
| KNR-03 | 🟡 | `monitoring_controller.tickScreenTimer` (RuleEngine tiap 1 dtk, §16 #35) | Pengingat ≤ 2 dtk setelah kondisi terpenuhi ✅ (test `reminders_test` KNR-03); latensi API 95 % < 1 dtk belum diukur |
| AKR-01 | ⏳ | — | Butuh data uji berlabel (precision/recall ≥ 90 %) |
| AKR-02 | ⏳ | — | Uji jarak ±5 cm pada 30–80 cm belum |
| PRV-01 | ✅ | `CameraFrame` hanya di memori; pencarian `writeAsBytes/toImage/MultipartFile/Blob` bersih | Tidak ada kolom BLOB/gambar |
| PRV-02 | ✅ | `AccountService`, `LocalDataCleaner` | Server hanya akun, transaksi, statistik angka |
| PRV-03 | ✅ | `camera_active_badge.dart` (Dashboard, menu lain, Sesi Cek Mata) | Indikator selalu tampil saat kamera menyala |
| KMN-01 | 🟡 | `network_security_config.xml` (cleartext hanya debug/profile) | Release HTTPS saja; TLS server produksi belum dideploy |
| KMN-02 | ✅ | `User` (`password_hash` hashed/bcrypt), Sanctum, `LoginThrottle` | 5× gagal → 429 5 mnt |
| KMN-03 | ✅ | Saldo = `SUM(credit_ledger.delta)`; notifikasi bersignature | Klien tidak pernah menambah saldo |
| USB-01 | ⏳ | — | Waktu onboarding + kalibrasi ≤ 3 mnt belum diukur |
| USB-02 | ✅ | `reminder_popup.dart` (`ExcludeFocus`, satu klik) | |
| PRT-01 | 🟡 | — | Android APK debug ✅; Windows ter-build hingga Tahap D, build setelah Tahap E belum terverifikasi; macOS/iOS butuh Mac |
| KDL-01 | ✅ | `metrics_repository` (sampel 60 dtk), `closeDangling` | Data hilang ≤ 1 mnt |
| KDL-02 | 🟡 | `MainActivity.kt` (layar mati), `stopForScreenOff` | Baterai ≤ 10 %/jam belum diukur |
| PML-01 | 🟡 | `lib/cv_engine/` terpisah dari UI | Flutter CV 77,5 %, kredit 88,7 %; backend tidak terukur |
| KSL-01 | ✅ | `privacy_onboarding_page.dart` | Penafian "bukan alat medis" |

Fitur resmi **Saran AI** (DOCS_SPEC §8.9, SAI-01..03) — kartu "Minta saran" di Dashboard (saat Mode AI) dan
Statistik; lewat backend `POST /ai/advice` (key Gemini hanya di server), hanya angka ringkasan
yang dikirim, saran statis bila gagal/429/offline. `.env` tidak lagi menjadi asset aplikasi.

Opsi debug (hanya `kDebugMode` / analyzer simulasi): "Isi data contoh 14 hari" di Statistik,
"Tambah 1 kredit" di Kredit, simulasi mata lelah/terlalu dekat, percepat 20-20-20.

## Menjalankan

1. Jalankan backend (sekali setup: lihat `backend/README.md`):
   ```bash
   cd backend
   php artisan migrate:fresh --seed   # sekali / bila ingin data awal bersih
   php artisan serve                  # http://127.0.0.1:8000
   ```
2. Jalankan aplikasi:
   ```bash
   flutter pub get
   flutter run -d windows             # bawaan: http://127.0.0.1:8000/api
   flutter run -d emulator-5554       # emulator Android: http://10.0.2.2:8000/api
   # HP fisik (satu Wi-Fi): php artisan serve --host=0.0.0.0, lalu
   flutter run -d <id-hp> --dart-define=API_BASE_URL=http://<IP-laptop>:8000/api
   # Tanpa server (repository tiruan):
   flutter run -d windows --dart-define=USE_REMOTE_API=false
   ```
   Ketik URL apa adanya, **tanpa** tanda kurung/format tautan.
3. Pemeriksaan:
   ```bash
   flutter analyze        # analisis statis
   flutter test           # unit & widget test (selalu memakai repository tiruan / HTTP tiruan)
   ```

Akun demo (seeder backend, juga terisi otomatis di form login build debug):
`demo@visionguard.id` / `password123`. Admin: `admin@visionguard.id` / `password123` di `http://127.0.0.1:8000/admin`.

Saran AI langsung ke Gemini tanpa server (debug saja):
`flutter run -d windows --dart-define=USE_REMOTE_API=false --dart-define=GEMINI_API_KEY=<key>`.

## Struktur Folder

```
lib/
├── main.dart                         # ProviderScope + runApp
├── app/                              # app shell, router (go_router), tema
├── core/constants/cv_constants.dart  # semua parameter SDD 2.5
├── cv_engine/                        # CV Engine (tanpa UI)
│   ├── camera_source.dart            # CameraSource
│   ├── face_analyzer.dart            # antarmuka FaceAnalyzer + Point2
│   ├── mediapipe_face_analyzer.dart  # MediaPipe Face Landmarker via tflite_flutter (Android/iOS)
│   ├── face_mesh_geometry.dart       # BlazeFace anchor, ROI, sampling YUV/BGRA, landmark → piksel, yaw
│   ├── dummy_face_analyzer.dart      # mode simulasi (fallback + test, opsi demo)
│   ├── blink_analyzer.dart           # EAR, blink rate, PERCLOS
│   ├── distance_estimator.dart       # d = f·D_iris / w_iris
│   ├── fatigue_scorer.dart           # skor 0-100 & level
│   └── cv_providers.dart             # provider + selectFaceAnalyzer (MediaPipe / fallback simulasi)
├── features/
│   ├── auth/         (data, application, presentation) — login, auto-login, lupa sandi, hapus akun
│   ├── background/   (data, application, presentation) — tray Windows, foreground service Android,
│   │                 layar mati, autostart, notifikasi saat jendela tersembunyi
│   ├── eye_check/    (application, presentation) — Sesi Cek Mata 2 menit (S-07, mobile)
│   ├── help/         (domain, presentation) — Bantuan & FAQ (ikon bantuan di setiap layar)
│   ├── onboarding/   (presentation)
│   ├── calibration/  (application, presentation)
│   ├── ai_assistant/ (data, application, presentation) — Saran AI (§8.9)
│   ├── calibration/  (data, application, presentation)
│   ├── credits/      (domain, data, application, presentation) — ApiCreditRepository (+ tiruan), beli via Midtrans, S-09
│   ├── monitoring/   (data, application, presentation)
│   ├── reminders/    (domain, application, data, presentation) — RuleEngine, TimerService, pop-up
│   ├── settings/     (data, application, presentation)
│   └── stats/        (data, application, presentation) — agregasi, SyncService → POST /stats/daily, grafik S-08
└── shared/widgets/                   # widget bersama (badge kamera aktif, tombol bantuan)
test/
├── cv_engine_test.dart               # uji rumus EAR, jarak, skor
├── mediapipe_face_analyzer_test.dart # konversi landmark sintetis, anchor, sampling, yaw, fallback
├── background_test.dart              # menu tray, jeda/lanjut, kamera bentrok + coba ulang, service, autostart
├── eye_check_test.dart               # hitungan Sesi Cek Mata, batal < 2 mnt, simpan sesi 'check'
├── help_test.dart                    # isi FAQ, halaman & tombol bantuan
├── reminders_test.dart               # RuleEngine, TimerService, tunda/fokus, verifikasi istirahat
├── stats_test.dart                   # agregasi daily_summaries, sinkron/offline, halaman Statistik
├── credits_test.dart                 # aktivasi hari §8.2, ledger, halaman Kredit
├── ai_advice_card_test.dart          # kartu Saran AI
└── ...                               # database, pengaturan, jaringan, widget
```

## Deteksi Wajah (Tahap D)

| Platform | Analyzer | Keterangan |
|---|---|---|
| Android | `MediaPipeFaceAnalyzer` | Image stream YUV420 (`camera_android_camerax`), target 10 fps |
| iOS | `MediaPipeFaceAnalyzer` (belum diuji) | Image stream BGRA8888 |
| Windows | `DummyFaceAnalyzer` — "Mode simulasi" | `camera_windows` 0.3.x belum menyediakan image stream (sempat ada di 0.2.5, dicabut di 0.2.6). Pratinjau kamera tetap asli, frame analisis tiruan. `tflite_flutter` di Windows juga butuh `libtensorflowlite_c-win.dll` manual |
| macOS / lainnya | `DummyFaceAnalyzer` | Belum didukung |

Pemilihan otomatis di `selectFaceAnalyzer()` (dipanggil `main.dart`): bila platform tidak
didukung atau model gagal dimuat (batas 15 dtk), aplikasi memakai mode simulasi dan Dashboard
menampilkan alasannya ("Mesin deteksi: Mode simulasi — …"). Opsi demo hanya ada di mode simulasi.

**Model** (`assets/models/`), diekstrak tanpa diubah dari bundel resmi
[`face_landmarker.task`](https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task)
(MediaPipe Face Landmarker, float16; diunduh 23 Nov 2026, SHA-256 bundel `64184e22…bc9ff`):

| Berkas | Isi | SHA-256 |
|---|---|---|
| `face_detector.tflite` | BlazeFace short range, input 128×128, output 896×16 + 896 | `b4578f35…0b152f` |
| `face_landmarks_detector.tflite` | Face Mesh V2, input 256×256, output 478×3 + skor kehadiran | `c7d54204…bd43d5` |

Sumber: Google MediaPipe — <https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker>.
Lisensi: **Apache License 2.0** (model card MediaPipe Face Mesh V2 & BlazeFace). `face_blendshapes.tflite`
dari bundel yang sama tidak dipakai. Runtime: `tflite_flutter` 0.12.1 (LiteRT 1.4.0, Apache 2.0).

## Latar Belakang, Sesi Cek Mata & Bantuan (Tahap E)

| Platform | Perilaku |
|---|---|
| **Windows** | Tombol tutup jendela menyembunyikan aplikasi ke **system tray** (pemberitahuan sekali). Klik ikon membuka jendela; klik kanan membuka menu: status, Jeda/Lanjut, Mode Fokus 30/60/90/120 (+ Akhiri), Buka Dashboard, Logout, Keluar. Selama tersembunyi, pengingat dikirim sebagai **notifikasi sistem**. **Autostart** di Pengaturan menulis `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\VisionGuard` dengan argumen `--autostart` (aplikasi langsung ke tray). |
| **Android** | Selama Mode AI berjalan: **foreground service** (`flutter_foreground_task`, tipe `camera`) + notifikasi permanen berisi status. **Layar mati → pemantauan berhenti** (BroadcastReceiver di `MainActivity.kt`, KDL-02). Plugin `camera` (CameraX) menutup kamera saat aplikasi tidak terlihat; pemantauan otomatis dijeda ("wajah tidak terdeteksi", PMT-05) dan kamera menyala lagi saat aplikasi dibuka. **Sesi Cek Mata** 2 menit dari Dashboard. |
| macOS / iOS | Belum: tray macOS & autostart macOS tidak diaktifkan; iOS tidak mendukung foreground service kamera. |

Semua platform: **Jeda/Lanjut** di Dashboard; kamera dipakai aplikasi lain → Mode Timer + coba
lagi tiap 60 detik; ikon **Bantuan** (?) di setiap layar membuka **Bantuan & FAQ** pada topik
layar tersebut (bisa dibuka tanpa login).

Paket baru: `tray_manager` ^0.8.3, `window_manager` ^0.6.0 (versi lebih baru butuh Flutter ≥ 3.50),
`flutter_foreground_task` ^11.0.3. `launch_at_startup` tidak dipakai karena bentrok `win32` 6
(`flutter_secure_storage`); autostart memakai `reg.exe` bawaan Windows.

## Catatan Privasi

Frame kamera hanya hidup di memori (`CameraFrame`) dan dibuang setelah dianalisis. Tidak ada kode yang menyimpan frame ke disk atau mengirimnya ke jaringan (SRS PRV-01).
