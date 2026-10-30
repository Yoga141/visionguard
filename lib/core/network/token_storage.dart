import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

/// Penyimpanan token Sanctum. Token wajib disimpan di penyimpanan aman
/// perangkat (DOCS_SPEC §4.3), bukan di SharedPreferences/berkas biasa.
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// Implementasi asli: Keychain (iOS/macOS), Keystore (Android),
/// Credential Locker (Windows).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: ApiConstants.tokenStorageKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: ApiConstants.tokenStorageKey, value: token);

  @override
  Future<void> delete() => _storage.delete(key: ApiConstants.tokenStorageKey);
}

/// Implementasi di memori untuk unit test.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}
