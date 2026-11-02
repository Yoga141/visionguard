# VisionGuard

Aplikasi Flutter berbasis *computer vision* untuk deteksi dini dan pencegahan kelelahan mata digital melalui analisis kedipan dan jarak pandang.

Mayoga Finanda (11241044) — Informatika. Dokumen acuan: SRS & SDD VisionGuard v1.0.

## Status: menuju Progress 50% (bagian 2 dari 3 selesai)

| Fitur | Status | Acuan |
|---|---|---|
| Arsitektur folder berbasis Riverpod (feature-first) | ✅ | SDD 3.2 |
| Login & Registrasi (repository tiruan; klien REST Laravel siap) | ✅ | S-01, UC-01, UC-02 |
| Onboarding Privasi + penafian medis | ✅ | S-02, UC-06, KLB-01 |
| Kalibrasi mata (baseline EAR, median 10 dtk) | ✅ | S-03, UC-07, KLB-02 |
| Kalibrasi jarak (focal length) + opsi lewati | ✅ | S-03, UC-08, KLB-03 |
| Kalibrasi tersimpan per kamera & minta ulang saat kamera diganti | ✅ | KLB-04 |
| Dashboard: BR, PERCLOS, jarak, skor, status kredit | ✅ | S-04, PMT-02..04 |
| Menu utama: Dashboard, Statistik, Kredit, Pengaturan (bottom nav / navigation rail) | ✅ | §7.4 |
| CameraSource (kamera asli / fallback simulasi) | ✅ | SDD 4.1 |
| Rumus EAR, blink rate, PERCLOS | ✅ | SDD 2.5.1 |
| Estimasi jarak dari diameter iris, dihaluskan median 1 detik | ✅ | SDD 2.5.2, §16 #6 |
| Skor kelelahan 50:30:20 (int, dievaluasi tiap 10 detik) + level 40/60 | ✅ | SDD 2.5.3, §16 #7 |
| Jeda perhitungan saat wajah tidak terdeteksi > 10 detik | ✅ | PMT-05 |
| Mode Timer 20-20-20 (TimerService, interval dari Pengaturan) | ✅ | UC-12 |
| RuleEngine: Istirahat > Jarak > Kedip > 20-20-20, durasi kondisi, cooldown 20/5/10 mnt, satu pengingat sekaligus | ✅ | §9.5, PNG-01..03, PNG-07 |
| TimerService: waktu layar kontinu (Mode AI & Timer, dijeda saat wajah hilang) | ✅ | Seq 4.23 |
| Pop-up pengingat kanan bawah: Oke/Tunda, tanpa ambil fokus, hilang 15 dtk → `dismissed` | ✅ | S-05, USB-02, UC-13 |
| Notifikasi sistem (Windows & Android) + aksi Tunda; cadangan pop-up | ✅ | S-06, §4.2 |
| Istirahat 20-20-20: hitung mundur 20 dtk + verifikasi kamera (≥ 15 dtk berpaling) | ✅ | PNG-04, PNG-05, UC-14 |
| Tunda 15/30/60 mnt & Mode Fokus 30/60/90/120 mnt (dari Dashboard, bisa diakhiri) | ✅ | PNG-06, UC-15 |
| Pencatatan respons pengingat ke tabel `alerts` | ✅ | D5, UC-13 |
| Opsi demo: simulasi mata lelah, simulasi terlalu dekat, percepat 20-20-20 (1 mnt) | ✅ (hanya analyzer simulasi) | — |
| Pengaturan: sensitivitas (τ 0,65/0,70/0,75), jenis pengingat, interval 10–60 mnt, reset bawaan | ✅ | S-10, PGT-01, UC-21 |
| Akun di Pengaturan: info, Logout, Hapus Akun (konfirmasi; permanen setelah backend) | ✅ / ⏳ | AKN-02, AKN-04 |
| Autostart | ⏳ tampil "segera hadir" | PGT-02 |
| Database lokal SQLite (drift): kalibrasi, sesi, metrik per menit, pengingat, ringkasan, pengaturan | ✅ | §12.3, KDL-01 |
| Saran AI (Gemini, khusus pengembangan) | ✅ (repository, belum di UI) | §17 |
| Unit & widget test (CV, database, pengaturan, jaringan, pengingat) | ✅ | PML-01 |
| Halaman Statistik & Kredit | ⏳ placeholder | S-08, S-09 |
| Deteksi wajah MediaPipe asli | ⏳ masih `DummyFaceAnalyzer` | SDD 4.1 |
| System tray (jeda/lanjut, Mode Fokus dari tray), backend Laravel, Midtrans | ⏳ | S-11 |

## Menjalankan

```bash
flutter pub get
flutter run            # pilih device: android / windows / chrome / dll
flutter test           # unit test rumus SDD 2.5
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
│   ├── monitoring/   (application, presentation)
│   └── reminders/    (domain, application, data, presentation) — RuleEngine, TimerService, pop-up
└── shared/widgets/                   # widget bersama (badge kamera aktif)
test/
├── cv_engine_test.dart               # uji rumus EAR, jarak, skor
├── reminders_test.dart               # RuleEngine, TimerService, tunda/fokus, verifikasi istirahat
└── widget_test.dart
```

## Catatan Privasi

Frame kamera hanya hidup di memori (`CameraFrame`) dan dibuang setelah dianalisis. Tidak ada kode yang menyimpan frame ke disk atau mengirimnya ke jaringan (SRS PRV-01).
