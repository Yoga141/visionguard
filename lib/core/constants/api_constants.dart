/// Konfigurasi koneksi ke REST API Laravel + Sanctum (DOCS_SPEC §4.3, §11).
class ApiConstants {
  ApiConstants._();

  /// Base URL API. Dapat ditimpa saat build:
  /// `flutter run --dart-define=API_BASE_URL=https://api.contoh.id/api`
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.visionguard.local/api',
  );

  /// `false` = pakai repository tiruan/pengembangan (backend belum dibangun).
  /// `true`  = pakai repository REST API (`ApiAuthRepository`, `ApiAiAdviceRepository`).
  /// Dapat ditimpa saat build: `--dart-define=USE_REMOTE_API=true`.
  static const bool useRemoteApi = bool.fromEnvironment('USE_REMOTE_API');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Kunci token Sanctum di penyimpanan aman perangkat.
  static const String tokenStorageKey = 'sanctum_token';
}
