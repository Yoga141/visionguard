# VisionGuard

Aplikasi Flutter berbasis *computer vision* untuk deteksi dini dan pencegahan kelelahan mata digital melalui analisis kedipan dan jarak pandang.

Mayoga Finanda (11241044) — Informatika. Dokumen acuan: SRS & SDD VisionGuard v1.0.

## Status: Progress 50%

Legenda: ✅ selesai · 🟡 sebagian · ⏳ belum. Backend Laravel + Midtrans belum ada, sehingga
fitur yang butuh server memakai repository **tiruan** (fake) di aplikasi.

| ID | Kebutuhan (DOCS_SPEC §5) | Status | Catatan |
|---|---|---|---|
| AKN-01 | Daftar dengan nama, email, kata sandi | 🟡 sebagian | Form & validasi selesai; `FakeAuthRepository`, klien REST `ApiAuthRepository` siap |
| AKN-02 | Login & logout | 🟡 sebagian | Pengguna: selesai (repository tiruan); admin (Filament) di luar repo ini |
| AKN-03 | Reset kata sandi via email | ⏳ belum | Tombol "Lupa kata sandi?" menampilkan info "setelah backend siap" |
| AKN-04 | Hapus akun | 🟡 sebagian | Konfirmasi di Pengaturan; penghapusan permanen setelah backend |
| KLB-01 | Penjelasan privasi & izin kamera | ✅ selesai | S-02, penafian medis |
| KLB-02 | Kalibrasi mata 10 detik (baseline EAR) | ✅ selesai | Median 10 dtk |
| KLB-03 | Focal length pada jarak acuan | ✅ selesai | + opsi lewati (FOV 60°) |
| KLB-04 | Kalibrasi ulang & per kamera | ✅ selesai | `calibrations.camera_id` |
| PMT-01 | Aktivasi Hari Pemantauan AI (kuota gratis / 1 kredit) | 🟡 sebagian | Algoritma §8.2 di `FakeCreditRepository`; endpoint server belum |
| PMT-02 | Deteksi kedipan & BR real-time | 🟡 sebagian | Rumus & pipeline selesai; landmark masih `DummyFaceAnalyzer` (MediaPipe belum) |
| PMT-03 | Estimasi jarak real-time | 🟡 sebagian | Median iris 1 dtk selesai; landmark masih simulasi |
| PMT-04 | PERCLOS & skor tiap 10 detik | 🟡 sebagian | Selesai di CV Engine; menunggu MediaPipe |
| PMT-05 | Jeda saat wajah hilang > 10 detik | ✅ selesai | `SessionEvaluator` |
| PMT-06 | Latar belakang (tray / foreground service) | ⏳ belum | |
| PMT-07 | Sesi Cek Mata 2 menit (mobile) | ⏳ belum | |
| PMT-08 | Beralih ke Mode Timer | 🟡 sebagian | Saat offline & hari belum aktif / pilihan saat kredit habis; deteksi kamera dipakai app lain belum |
| PNG-01 | Pengingat kedip | ✅ selesai | BR < 10 selama 3 mnt, cooldown 10 mnt |
| PNG-02 | Pengingat jarak | ✅ selesai | < 50/30 cm selama 10 dtk, cooldown 5 mnt |
| PNG-03 | Pengingat istirahat | ✅ selesai | Skor ≥ 60, cooldown 20 mnt |
| PNG-04 | 20-20-20 + hitung mundur 20 dtk | ✅ selesai | Mode AI & Mode Timer |
| PNG-05 | Verifikasi berpaling saat istirahat | ✅ selesai | ≥ 15 dari 20 dtk |
| PNG-06 | Tunda 15/30/60 & Mode Fokus | ✅ selesai | Mode Fokus dari Dashboard (tray belum) |
| PNG-07 | Cooldown per jenis | ✅ selesai | |
| STK-01 | Ringkasan harian | ✅ selesai | S-08 tab "Hari Ini": durasi, rata-rata BR/jarak/skor, pengingat, kepatuhan istirahat |
| STK-02 | Grafik tren 7 & 30 hari | ✅ selesai | `fl_chart`; "data belum cukup" bila < 2 hari |
| STK-03 | Sinkron ringkasan ke server | 🟡 sebagian | `daily_summaries.synced` + `FakeStatsRepository`; `POST /stats/daily` belum |
| KRD-01 | Kuota gratis, saldo, status hari ini | 🟡 sebagian | S-09 & Dashboard selesai; data dari `FakeCreditRepository` |
| KRD-02 | Beli paket via Midtrans | ⏳ belum | Daftar paket + tombol Beli → dialog "setelah backend siap" |
| KRD-03 | Kredit bertambah setelah pembayaran | ⏳ belum | Butuh notifikasi Midtrans di server |
| KRD-04 | Riwayat transaksi & pemakaian | 🟡 sebagian | UI selesai; data tiruan |
| PGT-01 | Sensitivitas, jenis pengingat, interval | ✅ selesai | τ 0,65/0,70/0,75; interval 10–60 mnt |
| PGT-02 | Autostart | ⏳ belum | Tampil "segera hadir" |

Fitur tambahan: **Saran AI** (§17) — kartu "Minta saran" di Dashboard (saat Mode AI) dan
Statistik; hanya angka ringkasan yang dikirim, saran statis bila key kosong/gagal. Panggilan
Gemini langsung **khusus pengembangan**.

Opsi debug (hanya `kDebugMode` / analyzer simulasi): "Isi data contoh 14 hari" di Statistik,
"Tambah 1 kredit" di Kredit, simulasi mata lelah/terlalu dekat, percepat 20-20-20.

## Menjalankan

```bash
flutter pub get
flutter run            # pilih device: android / windows / chrome / dll
flutter analyze        # analisis statis
flutter test           # unit & widget test
```

Akun demo: `demo@visionguard.id` / `password123`

## Struktur Folder

```
lib/
├── main.dart                         # ProviderScope + runApp
├── app/                              # app shell, router (go_router), tema
├── core/constants/cv_constants.dart  # semua parameter SDD 2.5
├── cv_engine/                        # CV Engine (tanpa UI)
│   ├── camera_source.dart            # CameraSource
│   ├── face_analyzer.dart            # antarmuka FaceAnalyzer + Point2
│   ├── dummy_face_analyzer.dart      # landmark sintetis (pengganti MediaPipe)
│   ├── blink_analyzer.dart           # EAR, blink rate, PERCLOS
│   ├── distance_estimator.dart       # d = f·D_iris / w_iris
│   ├── fatigue_scorer.dart           # skor 0-100 & level
│   └── cv_providers.dart             # provider Riverpod CV Engine
├── features/
│   ├── auth/         (data, application, presentation)
│   ├── onboarding/   (presentation)
│   ├── calibration/  (application, presentation)
│   ├── ai_assistant/ (data, application, presentation) — Saran AI (§17)
│   ├── calibration/  (data, application, presentation)
│   ├── credits/      (domain, data, application, presentation) — CreditRepository tiruan, S-09
│   ├── monitoring/   (data, application, presentation)
│   ├── reminders/    (domain, application, data, presentation) — RuleEngine, TimerService, pop-up
│   ├── settings/     (data, application, presentation)
│   └── stats/        (data, application, presentation) — agregasi, sinkron tiruan, grafik S-08
└── shared/widgets/                   # widget bersama (badge kamera aktif)
test/
├── cv_engine_test.dart               # uji rumus EAR, jarak, skor
├── reminders_test.dart               # RuleEngine, TimerService, tunda/fokus, verifikasi istirahat
├── stats_test.dart                   # agregasi daily_summaries, sinkron/offline, halaman Statistik
├── credits_test.dart                 # aktivasi hari §8.2, ledger, halaman Kredit
├── ai_advice_card_test.dart          # kartu Saran AI
└── ...                               # database, pengaturan, jaringan, widget
```

## Catatan Privasi

Frame kamera hanya hidup di memori (`CameraFrame`) dan dibuang setelah dianalisis. Tidak ada kode yang menyimpan frame ke disk atau mengirimnya ke jaringan (SRS PRV-01).
