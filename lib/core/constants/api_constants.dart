import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Konfigurasi koneksi ke REST API Laravel + Sanctum (DOCS_SPEC §4.3, §11).
class ApiConstants {
  ApiConstants._();

  /// Base URL dari `--dart-define=API_BASE_URL=...` (mis. HP fisik:
  /// `http://192.168.1.10:8000/api`). Kosong → [defaultBaseUrl].
  static const String _baseUrlDefine = String.fromEnvironment('API_BASE_URL');

  /// Backend pengembangan lokal (`php artisan serve`):
  /// - Windows/macOS/iOS simulator: `http://127.0.0.1:8000/api`
  /// - Emulator Android: `http://10.0.2.2:8000/api` (alias host laptop)
  static String get defaultBaseUrl {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    return 'http://127.0.0.1:8000/api';
  }

  static String get baseUrl => _baseUrlDefine.isNotEmpty ? _baseUrlDefine : defaultBaseUrl;

  /// `--dart-define=USE_REMOTE_API=false` → repository tiruan (tanpa server).
  static const bool _useRemoteApiDefine = bool.fromEnvironment('USE_REMOTE_API', defaultValue: true);

  /// `true` (bawaan) = backend Laravel asli. Di bawah `flutter test` selalu
  /// `false`, sehingga test memakai repository tiruan kecuali meng-override
  /// provider secara eksplisit (test repository API memakai Dio tiruan).
  static bool get useRemoteApi => _useRemoteApiDefine && !_runningUnderFlutterTest;

  static final bool _runningUnderFlutterTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Batas waktu baca/tulis token di penyimpanan aman. Lewat dari ini dianggap
  /// gagal agar request tidak menggantung (mis. secure storage tidak merespons).
  static const Duration tokenStorageTimeout = Duration(seconds: 5);

  /// Batas waktu total satu aksi login/registrasi di UI. Lebih besar dari
  /// connect + receive + token storage, sehingga hanya terpicu bila ada yang
  /// benar-benar menggantung. Setelah ini spinner pasti berhenti.
  static const Duration authDeadline = Duration(seconds: 35);

  /// Kunci token Sanctum di penyimpanan aman perangkat.
  static const String tokenStorageKey = 'sanctum_token';

  /// Batas ringkasan harian per `POST /stats/daily` (API_CONTRACT.md).
  static const int statsMaxBatch = 31;
}
