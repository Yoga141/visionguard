# VisionGuard

Aplikasi Flutter berbasis *computer vision* untuk deteksi dini dan pencegahan kelelahan mata digital melalui analisis kedipan dan jarak pandang.

Mayoga Finanda (11241044) — Informatika. Dokumen acuan: SRS & SDD VisionGuard v1.0.

## Status: Tahap A–E (backend, MediaPipe di Android, latar belakang & bantuan)

Legenda: ✅ selesai · 🟡 sebagian · ⏳ belum. Backend Laravel ada di `backend/` (lihat
`backend/README.md` dan `API_CONTRACT.md`) dan aplikasi memakainya **secara bawaan** sejak Tahap C.
Repository tiruan hanya untuk test dan `--dart-define=USE_REMOTE_API=false`. Detail tahap: `ROADMAP.md`.

| ID | Kebutuhan (DOCS_SPEC §5) | Status | Catatan |
|---|---|---|---|
| AKN-01 | Daftar dengan nama, email, kata sandi | ✅ selesai | `POST /auth/register`; 422 email terpakai ditampilkan per kolom |
| AKN-02 | Login & logout | ✅ selesai | Token di secure storage, auto-login (`GET /me`), logout mencabut token; admin lewat Filament `/admin` |
| AKN-03 | Reset kata sandi via email | ✅ selesai | Halaman "Lupa kata sandi" → `POST /auth/forgot-password` → tautan ke halaman web sandi baru |
| AKN-04 | Hapus akun | ✅ selesai | Kata sandi → `DELETE /me` (403 bila salah) → semua data lokal dihapus → Login |
| KLB-01 | Penjelasan privasi & izin kamera | ✅ selesai | S-02, penafian medis |
| KLB-02 | Kalibrasi mata 10 detik (baseline EAR) | ✅ selesai | Median 10 dtk |
| KLB-03 | Focal length pada jarak acuan | ✅ selesai | + opsi lewati (FOV 60°) |
| KLB-04 | Kalibrasi ulang & per kamera | ✅ selesai | `calibrations.camera_id` |
| PMT-01 | Aktivasi Hari Pemantauan AI (kuota gratis / 1 kredit) | ✅ selesai | `POST /monitoring-days/activate` (§8.2 di server); 402 → tawarkan Beli atau Mode Timer |
| PMT-02 | Deteksi kedipan & BR real-time | 🟡 sebagian | `MediaPipeFaceAnalyzer` (Android/iOS); Windows & desktop lain → mode simulasi. Uji di HP asli belum |
| PMT-03 | Estimasi jarak real-time | 🟡 sebagian | Iris 469↔471 / 474↔476 dari MediaPipe; uji penggaris 30/50/80 cm belum |
| PMT-04 | PERCLOS & skor tiap 10 detik | 🟡 sebagian | Selesai di CV Engine; menunggu uji dengan wajah asli |
| PMT-05 | Jeda saat wajah hilang > 10 detik | ✅ selesai | `SessionEvaluator` |
| PMT-06 | Latar belakang (tray / foreground service) | 🟡 sebagian | Windows: tutup jendela → tray, menu S-11, pengingat via notifikasi. Android: foreground service `camera` + notifikasi permanen selama Mode AI; kamera berhenti saat aplikasi tak terlihat (batasan plugin, §16 #32). Belum diuji manual |
| PMT-07 | Sesi Cek Mata 2 menit (mobile) | 🟡 sebagian | S-07: cek status hari → aktivasi → teks bacaan 2 mnt → skor + Saran AI; batal < 2 mnt tidak disimpan; `sessions.mode='check'`. Belum diuji di HP |
| PMT-08 | Beralih ke Mode Timer | ✅ selesai | Offline & hari belum aktif → Timer; kamera dipakai app lain / izin ditolak → Timer + coba lagi tiap 60 dtk, kembali ke AI tanpa memotong kredit |
| PNG-01 | Pengingat kedip | ✅ selesai | BR < 10 selama 3 mnt, cooldown 10 mnt |
| PNG-02 | Pengingat jarak | ✅ selesai | < 50/30 cm selama 10 dtk, cooldown 5 mnt |
| PNG-03 | Pengingat istirahat | ✅ selesai | Skor ≥ 60, cooldown 20 mnt |
| PNG-04 | 20-20-20 + hitung mundur 20 dtk | ✅ selesai | Mode AI & Mode Timer |
| PNG-05 | Verifikasi berpaling saat istirahat | ✅ selesai | ≥ 15 dari 20 dtk |
| PNG-06 | Tunda 15/30/60 & Mode Fokus | ✅ selesai | Mode Fokus dari Dashboard (tray belum) |
| PNG-07 | Cooldown per jenis | ✅ selesai | |
| STK-01 | Ringkasan harian | ✅ selesai | S-08 tab "Hari Ini": durasi, rata-rata BR/jarak/skor, pengingat, kepatuhan istirahat |
| STK-02 | Grafik tren 7 & 30 hari | ✅ selesai | `fl_chart`; "data belum cukup" bila < 2 hari |
| STK-03 | Sinkron ringkasan ke server | ✅ selesai | `SyncService` → `POST /stats/daily` (batch); tren `GET /stats`; offline → data lokal |
| KRD-01 | Kuota gratis, saldo, status hari ini | ✅ selesai | `GET /credits/status` (saldo dari ledger server) |
| KRD-02 | Beli paket via Midtrans | 🟡 sebagian | `POST /orders` → halaman Snap di browser → "Muat ulang status"; uji Sandbox manual belum |
| KRD-03 | Kredit bertambah setelah pembayaran | 🟡 sebagian | Server: notifikasi bersignature + idempoten; teruji otomatis & mode simulasi, Sandbox manual belum |
| KRD-04 | Riwayat transaksi & pemakaian | ✅ selesai | `GET /credits/history` |
| PGT-01 | Sensitivitas, jenis pengingat, interval | ✅ selesai | τ 0,65/0,70/0,75; interval 10–60 mnt |
| PGT-02 | Autostart | 🟡 sebagian | Windows: toggle Pengaturan → `HKCU\…\Run` (`--autostart` → langsung ke tray). macOS belum. Belum diuji login ulang Windows |
| ADM-01 | Admin kelola paket kredit | ✅ selesai | Filament `/admin` → Paket Kredit (paket pernah dibeli tidak bisa dihapus) |
| ADM-02 | Admin lihat pengguna & transaksi | ✅ selesai | Filament → Transaksi (filter status & tanggal) dan Pengguna (saldo) |
| ADM-03 | Admin sesuaikan kredit + alasan | ✅ selesai | Aksi "Sesuaikan kredit" (alasan wajib, saldo akhir ≥ 0) |

Fitur tambahan: **Saran AI** (§17) — kartu "Minta saran" di Dashboard (saat Mode AI) dan
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
│   ├── ai_assistant/ (data, application, presentation) — Saran AI (§17)
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
