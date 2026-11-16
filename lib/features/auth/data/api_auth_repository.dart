import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'auth_repository.dart';

/// Implementasi [AuthRepository] ke REST API Laravel + Sanctum
/// (DOCS_SPEC §8.7, §11, API_CONTRACT.md).
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
      throw AuthException(friendlyErrorMessage(e));
    }
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    try {
      final res = await _api.post('/auth/register', body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'timezone': _timezoneGuess(),
        ..._deviceInfo,
      }..removeWhere((_, v) => v == null));
      return await _saveSession(res);
    } on ValidationException catch (e) {
      throw AuthException(e.firstError('email') ??
          e.firstError('password') ??
          e.firstError('name') ??
          friendlyErrorMessage(e));
    } on ApiException catch (e) {
      throw AuthException(friendlyErrorMessage(e));
    }
  }

  @override
  Future<AppUser?> restoreSession() async {
    String? token;
    try {
      token = await _api.tokenStorage.read().timeout(ApiConstants.tokenStorageTimeout);
    } catch (e) {
      debugPrint('ApiAuthRepository: token tidak dapat dibaca (${e.runtimeType}).');
      return null;
    }
    if (token == null || token.isEmpty) return null;

    try {
      final res = await _api.get('/me');
      final user = res['user'];
      if (user is! Map || user['name'] is! String || user['email'] is! String) return null;
      return AppUser(
        name: user['name'] as String,
        email: user['email'] as String,
        id: user['id'] is int ? user['id'] as int : null,
      );
    } on UnauthorizedException {
      // Token dicabut/kedaluwarsa → hapus, pengguna masuk lagi.
      await _deleteTokenQuietly();
      return null;
    } on NetworkException catch (e) {
      throw AuthOfflineException(e.message);
    } on ApiException catch (e) {
      // 5xx dll.: jangan buang token; perlakukan seperti offline.
      throw AuthOfflineException(friendlyErrorMessage(e));
    }
  }

  @override
  Future<String> forgotPassword(String email) async {
    try {
      final res = await _api.post('/auth/forgot-password', body: {'email': email.trim().toLowerCase()});
      final message = res['message'];
      return message is String && message.isNotEmpty
          ? message
          : 'Tautan reset kata sandi telah dikirim ke email Anda. Berlaku 60 menit.';
    } on NotFoundException {
      throw AuthException('Email tidak terdaftar.');
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        throw AuthException('Tautan baru saja dikirim. Tunggu sebentar sebelum meminta lagi.');
      }
      throw AuthException(friendlyErrorMessage(e));
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    try {
      await _api.delete('/me', body: {'password': password});
    } on ForbiddenException {
      throw AuthException('Kata sandi salah. Akun tidak dihapus.');
    } on UnauthorizedException {
      throw AuthException('Sesi Anda berakhir. Silakan masuk lagi, lalu ulangi hapus akun.');
    } on ApiException catch (e) {
      throw AuthException(friendlyErrorMessage(e));
    }
    await _deleteTokenQuietly();
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Offline/token sudah tidak berlaku: tetap hapus token lokal (§8.7).
    } finally {
      await _deleteTokenQuietly();
    }
  }

  Future<void> _deleteTokenQuietly() async {
    try {
      await _api.tokenStorage.delete().timeout(ApiConstants.tokenStorageTimeout);
    } catch (e) {
      debugPrint('ApiAuthRepository: token lokal gagal dihapus (${e.runtimeType}).');
    }
  }

  Future<AppUser> _saveSession(Map<String, dynamic> res) async {
    final token = res['token'];
    final user = res['user'];
    if (token is! String ||
        token.isEmpty ||
        user is! Map ||
        user['name'] is! String ||
        user['email'] is! String) {
      throw AuthException('Respons server tidak dikenali.');
    }
    try {
      await _api.tokenStorage.write(token).timeout(ApiConstants.tokenStorageTimeout);
    } catch (e) {
      debugPrint('ApiAuthRepository: token gagal disimpan (${e.runtimeType}).');
      throw AuthException(
        'Login berhasil, tetapi sesi tidak dapat disimpan di perangkat ini. Coba lagi.',
      );
    }
    final deviceId = res['device_id'];
    return AppUser(
      name: user['name'] as String,
      email: user['email'] as String,
      id: user['id'] is int ? user['id'] as int : null,
      deviceId: deviceId is int ? deviceId : null,
    );
  }

  /// Zona waktu akun (§8.1). Dart tidak memberi nama IANA; WIB/WITA/WIT
  /// dipetakan dari offset, selain itu biarkan server memakai bawaan.
  static String? _timezoneGuess() {
    return switch (DateTime.now().timeZoneOffset.inHours) {
      7 => 'Asia/Jakarta',
      8 => 'Asia/Makassar',
      9 => 'Asia/Jayapura',
      _ => null,
    };
  }
}
