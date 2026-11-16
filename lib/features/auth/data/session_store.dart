import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/settings_repository.dart';
import 'auth_repository.dart';

final sessionStoreProvider =
    Provider<SessionStore>((ref) => SessionStore(ref.watch(settingsRepositoryProvider)));

/// Data sesi non-rahasia di tabel lokal `settings` (DOCS_SPEC §12.3 D10).
/// Token Sanctum **tidak** disimpan di sini (tetap di flutter_secure_storage).
///
/// - `auth.device_id`: `devices.id` perangkat ini dari respons login.
/// - `auth.cached_user`: nama & email terakhir, untuk auto-login saat offline.
/// - `privacy_accepted:<email>`: persetujuan privasi (UC-06) per akun.
class SessionStore {
  SessionStore(this._settings);

  final SettingsRepository _settings;

  static const _deviceKey = 'auth.device_id';
  static const _userKey = 'auth.cached_user';
  static String _privacyKey(String email) => 'privacy_accepted:${email.trim().toLowerCase()}';

  Future<int?> deviceId() async => int.tryParse(await _settings.get(_deviceKey) ?? '');

  Future<void> saveUser(AppUser user) async {
    await _settings.set(_userKey, jsonEncode({'name': user.name, 'email': user.email, 'id': user.id}));
    if (user.deviceId != null) await _settings.set(_deviceKey, '${user.deviceId}');
  }

  Future<AppUser?> cachedUser() async {
    final raw = await _settings.get(_userKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AppUser(
        name: m['name'] as String,
        email: m['email'] as String,
        id: m['id'] as int?,
        deviceId: await deviceId(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Logout: profil & device id dibuang (persetujuan privasi per akun tetap).
  Future<void> clearUser() async {
    await _settings.remove(_userKey);
    await _settings.remove(_deviceKey);
  }

  Future<bool> privacyAccepted(String email) async => await _settings.get(_privacyKey(email)) == 'true';

  Future<void> setPrivacyAccepted(String email) => _settings.set(_privacyKey(email), 'true');
}
