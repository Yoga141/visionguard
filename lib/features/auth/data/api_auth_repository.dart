import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'auth_repository.dart';

/// Implementasi [AuthRepository] ke REST API Laravel + Sanctum
/// (DOCS_SPEC §8.7, §11).
///
/// Belum dipakai selama `ApiConstants.useRemoteApi == false`.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  /// Identitas perangkat untuk tabel `devices` (platform, device_name).
  static Map<String, String> get _deviceInfo {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
    return {'platform': platform, 'device_name': 'VisionGuard $platform'};
  }

  @override
  Future<AppUser> login(String email, String password) async {
    try {
      final res = await _api.post('/auth/login', body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        ..._deviceInfo,
      });
      return await _saveSession(res);
    } on UnauthorizedException {
      throw AuthException('Email atau kata sandi salah.');
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        // SRS UC-02 alur alternatif 2 / KMN-02
        throw AuthException('Terlalu banyak percobaan. Coba lagi dalam 5 menit.');
      }
      throw AuthException(e.message);
    }
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    try {
      final res = await _api.post('/auth/register', body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        ..._deviceInfo,
      });
      return await _saveSession(res);
    } on ValidationException catch (e) {
      throw AuthException(e.firstError('email') ??
          e.firstError('password') ??
          e.firstError('name') ??
          e.message);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Offline/token sudah tidak berlaku: tetap hapus token lokal (§8.7).
    } finally {
      await _api.tokenStorage.delete();
    }
  }

  Future<AppUser> _saveSession(Map<String, dynamic> res) async {
    final token = res['token'];
    final user = res['user'];
    if (token is! String || user is! Map) {
      throw AuthException('Respons server tidak dikenali.');
    }
    await _api.tokenStorage.write(token);
    return AppUser(name: user['name'] as String, email: user['email'] as String);
  }
}
