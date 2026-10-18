# VisionGuard

Aplikasi Flutter berbasis *computer vision* untuk deteksi dini dan pencegahan kelelahan mata digital melalui analisis kedipan dan jarak pandang.

Mayoga Finanda (11241044) — Informatika. Dokumen acuan: SRS & SDD VisionGuard v1.0.

## Status: Progress 30%

| Fitur | Status | Acuan |
|---|---|---|
| Arsitektur folder berbasis Riverpod (feature-first) | ✅ | SDD 3.2 |
| Login & Registrasi (repository tiruan) | ✅ | S-01, UC-01, UC-02 |
| Onboarding Privasi + penafian medis | ✅ | S-02, UC-06, KLB-01 |
| Kalibrasi mata (baseline EAR, median 10 dtk) | ✅ | S-03, UC-07, KLB-02 |
| Kalibrasi jarak (focal length) + opsi lewati | ✅ | S-03, UC-08, KLB-03 |
| Dashboard: BR, PERCLOS, jarak, skor, status kredit | ✅ | S-04, PMT-02..04 |
| CameraSource (kamera asli / fallback simulasi) | ✅ | SDD 4.1 |
| Rumus EAR, blink rate, PERCLOS | ✅ | SDD 2.5.1 |
| Estimasi jarak dari diameter iris | ✅ | SDD 2.5.2 |
| Skor kelelahan 50:30:20 + level | ✅ | SDD 2.5.3 |
| Mode Timer 20-20-20 | ✅ (dasar) | UC-12 |
| Unit test rumus CV | ✅ | PML-01 |
| Deteksi wajah MediaPipe asli | ⏳ masih `DummyFaceAnalyzer` | SDD 4.1 |
| Pengingat & cooldown, statistik, SQLite, backend Laravel, Midtrans | ⏳ | — |

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
│   └── monitoring/   (application, presentation)
└── shared/widgets/                   # widget bersama (badge kamera aktif)
test/
├── cv_engine_test.dart               # uji rumus EAR, jarak, skor
└── widget_test.dart
```

## Catatan Privasi

Frame kamera hanya hidup di memori (`CameraFrame`) dan dibuang setelah dianalisis. Tidak ada kode yang menyimpan frame ke disk atau mengirimnya ke jaringan (SRS PRV-01).
