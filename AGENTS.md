# AGENTS.md — VisionGuard

Instruksi tunggal untuk semua AI coding assistant (Claude Code, OpenCode, Antigravity, dll.).

## 1. Wajib dibaca dulu

- **Baca `DOCS_SPEC.md` sebelum mengerjakan apa pun.** Dokumen itu adalah sumber kebenaran fitur, alur, database, API, dan aturan bisnis (diringkas dari SRS & SDD VisionGuard v1.0).
- Jika kode bertentangan dengan `DOCS_SPEC.md`, **ikuti `DOCS_SPEC.md`**.
- Jika suatu hal **belum diatur** di `DOCS_SPEC.md` atau termasuk **§16 (Inkonsistensi & Keputusan Terbuka)**, **tanyakan dulu** ke pengguna sebelum memutuskan.

## 2. Ringkasan proyek

VisionGuard adalah aplikasi Flutter (Windows, macOS, Android, iOS) untuk deteksi dini kelelahan mata digital. Kamera dipakai untuk menghitung blink rate, PERCLOS, dan jarak wajah ke layar secara *on-device*, lalu digabung menjadi skor kelelahan 0–100 yang memicu pengingat. Backend (Laravel + MySQL, Midtrans) berada di luar repo ini.

## 3. Stack

- **Flutter** (Dart SDK `^3.5.0`)
- **State management:** `flutter_riverpod` 2.x
- **Navigasi:** `go_router` 14
- **Kamera:** `camera` / `camera_windows`
- **Backend:** Laravel + Sanctum + MySQL sesuai SRS/SDD (di luar repo ini).
- **Jaringan:** `dio` (REST JSON ke Laravel) + `flutter_secure_storage` (token Sanctum). Belum terhubung ke server sungguhan.
- **Saran AI (fitur tambahan, DOCS_SPEC §17):** `google_generative_ai` + `flutter_dotenv` (`GEMINI_API_KEY` di `.env`). Pemanggilan langsung dari klien **khusus pengembangan**; versi final wajib lewat backend `POST /ai/advice`.
- **Database lokal:** SQLite via `drift` + `drift_flutter` (file di folder `getApplicationSupportDirectory` dari `path_provider`), skema persis DOCS_SPEC §12.3. Kode `app_database.g.dart` dihasilkan `drift_dev` + `build_runner`.
- Direncanakan (masih dikomentari di `pubspec.yaml`): `tflite_flutter`, `flutter_local_notifications`
- **Firebase tidak dipakai** (DOCS_SPEC §16 #13). Jangan menambahkannya kembali tanpa izin.

## 4. Struktur `lib/`

```
lib/
├── main.dart
├── app/                  # app.dart, router.dart (go_router + StatefulShellRoute), theme.dart,
│                         # main_shell.dart (menu utama §7.4: bottom nav / navigation rail)
├── core/
│   ├── constants/        # cv_constants.dart — satu-satunya tempat konstanta CV & ambang pengingat
│   │                     # api_constants.dart — base URL, flag useRemoteApi, timeout
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
│   │                     # data/api_ai_advice_repository.dart (POST /ai/advice, belum aktif),
│   │                     # application/ai_advice_provider.dart
│   ├── auth/             # auth_repository (kontrak + Fake), api_auth_repository,
│   │                     # auth_controller, login_page
│   ├── calibration/      # data/calibration_repository (per camera_id, KLB-04),
│   │                     # calibration_controller, calibration_page
│   ├── credits/          # presentation/credits_page (S-09, placeholder)
│   ├── monitoring/       # data/session_repository, metrics_repository (sampel 60 dtk,
│   │                     # retensi 30 hari, ringkasan harian), alert_repository;
│   │                     # monitoring_controller, dashboard_page
│   ├── onboarding/       # privacy_onboarding_page
│   ├── settings/         # data/settings_repository (key-value),
│   │                     # application/settings_controller (AppSettings, Sensitivity → τ),
│   │                     # presentation/settings_page (S-10, akun & logout)
│   └── stats/            # presentation/statistics_page (S-08, placeholder)
└── shared/
    └── widgets/          # camera_active_badge.dart, coming_soon.dart
```

Test ada di `test/` (`cv_engine_test.dart`, `network_test.dart`, `ai_advice_test.dart`, `database_test.dart`, `local_storage_flow_test.dart`, `settings_test.dart`, `widget_test.dart`). Test database memakai SQLite in-memory (`AppDatabase(NativeDatabase.memory())`, override `appDatabaseProvider`).

**Beralih ke backend asli:** selama `ApiConstants.useRemoteApi == false`, auth memakai `FakeAuthRepository` dan Saran AI memakai `DirectGeminiAdviceRepository`. Saat backend siap, jalankan dengan `--dart-define=USE_REMOTE_API=true --dart-define=API_BASE_URL=https://.../api` (beralih ke `ApiAuthRepository` dan `ApiAiAdviceRepository`).

## 5. Perintah penting

```bash
flutter pub get          # pasang dependensi
dart run build_runner build   # buat ulang app_database.g.dart setelah mengubah tabel
flutter analyze          # analisis statis
flutter test             # jalankan unit & widget test
flutter run -d windows   # jalankan aplikasi di Windows
```

> Build Windows membutuhkan komponen Visual Studio **"C++ ATL for latest build tools"** (dipakai oleh `flutter_secure_storage_windows`).

## 6. Aturan

1. **Jangan upgrade versi major** dependensi apa pun (Flutter SDK, Riverpod, go_router, dll.) tanpa izin pengguna.
2. **`lib/cv_engine/` tidak boleh bergantung pada UI** — tidak meng-import `package:flutter/material.dart`, widget, atau modul `features/*/presentation`. UI hanya membaca state lewat Riverpod.
3. **Frame kamera tidak boleh disimpan atau dikirim ke mana pun** — tidak ke disk, log, cache, database lokal, Gemini, maupun jaringan. Frame berhenti di CV Engine. Database lokal hanya menyimpan angka; jangan menambah kolom BLOB/gambar.
4. **Konstanta CV** (ambang EAR, PERCLOS, jarak, bobot skor, dll.) **hanya** didefinisikan di `lib/core/constants/cv_constants.dart`; jangan hard-code di tempat lain.
5. **Setelah mengubah kode**, jalankan `flutter analyze` dan `flutter test` sampai **bersih** (tanpa error, warning, maupun test gagal).
6. Patuhi juga panduan kepatuhan di `DOCS_SPEC.md` §15. Untuk Saran AI, patuhi §17: hanya angka ringkasan yang boleh dikirim.
7. **DILARANG** menjalankan `git commit`, `git push`, `git reset`, `git clean`, atau perintah git lain yang mengubah riwayat/remote. Commit dan push hanya dilakukan oleh pengguna. Jangan pernah menambahkan baris `Co-Authored-By`.
