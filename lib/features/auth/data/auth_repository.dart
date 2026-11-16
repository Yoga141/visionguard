/// Kontrak akses data akun (UC-01..UC-05). Implementasi asli:
/// `ApiAuthRepository` (REST API Laravel + Sanctum, API_CONTRACT.md).
abstract class AuthRepository {
  Future<AppUser> login(String email, String password);
  Future<AppUser> register(String name, String email, String password);

  /// Auto-login saat aplikasi dibuka: token tersimpan → `GET /me`.
  /// - `null`: belum ada sesi, atau token tidak berlaku lagi (dihapus).
  /// - [AuthOfflineException]: ada token tetapi server tidak terjangkau.
  Future<AppUser?> restoreSession();

  /// UC-03: kirim tautan reset ke email. Mengembalikan pesan sukses.
  Future<String> forgotPassword(String email);

  /// UC-05: hapus akun di server (verifikasi kata sandi), lalu cabut token lokal.
  /// [AuthException] bila kata sandi salah (403) atau gagal.
  Future<void> deleteAccount(String password);

  /// Mencabut token perangkat (UC-04). Tidak melempar exception walau offline.
  Future<void> logout();
}

class AppUser {
  const AppUser({required this.name, required this.email, this.id, this.deviceId});

  final String name;
  final String email;

  /// `users.id` di server (null untuk akun tiruan).
  final int? id;

  /// `devices.id` perangkat ini, dari respons login/registrasi. Dipakai
  /// `POST /monitoring-days/activate` dan `POST /stats/daily`.
  final int? deviceId;

  AppUser copyWith({int? deviceId}) =>
      AppUser(name: name, email: email, id: id, deviceId: deviceId ?? this.deviceId);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Ada sesi tersimpan, tetapi server tidak dapat dihubungi saat auto-login.
class AuthOfflineException extends AuthException {
  AuthOfflineException([super.message = 'Tidak dapat terhubung ke server.']);
}

/// Repository tiruan (test & `--dart-define=USE_REMOTE_API=false`).
/// Akun demo: demo@visionguard.id / password123
class FakeAuthRepository implements AuthRepository {
  final Map<String, ({String name, String password})> _users = {
    'demo@visionguard.id': (name: 'Pengguna Demo', password: 'password123'),
  };
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  /// Sesi yang "tersimpan" (meniru token di secure storage).
  AppUser? _session;

  /// Bila true, [restoreSession] meniru server tidak terjangkau.
  bool offline = false;

  @override
  Future<AppUser> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600)); // simulasi jaringan
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      throw AuthException('Terlalu banyak percobaan. Coba lagi dalam 5 menit.');
    }
    final key = email.trim().toLowerCase();
    final u = _users[key];
    if (u == null || u.password != password) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        // SRS UC-02 alur alternatif 2 / KMN-02
        _lockedUntil = now.add(const Duration(minutes: 5));
        _failedAttempts = 0;
      }
      throw AuthException('Email atau kata sandi salah.');
    }
    _failedAttempts = 0;
    return _session = AppUser(name: u.name, email: key, deviceId: 1);
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw AuthException('Email sudah terdaftar. Silakan login atau reset kata sandi.');
    }
    _users[key] = (name: name.trim(), password: password);
    return _session = AppUser(name: name.trim(), email: key, deviceId: 1);
  }

  @override
  Future<AppUser?> restoreSession() async {
    if (_session != null && offline) throw AuthOfflineException();
    return _session;
  }

  @override
  Future<String> forgotPassword(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!_users.containsKey(email.trim().toLowerCase())) {
      throw AuthException('Email tidak terdaftar.');
    }
    return 'Tautan reset kata sandi telah dikirim ke email Anda. Berlaku 60 menit.';
  }

  @override
  Future<void> deleteAccount(String password) async {
    final s = _session;
    if (s == null) throw AuthException('Sesi Anda berakhir. Silakan masuk lagi.');
    if (_users[s.email]?.password != password) {
      throw AuthException('Kata sandi salah. Akun tidak dihapus.');
    }
    _users.remove(s.email);
    _session = null;
  }

  @override
  Future<void> logout() async => _session = null;
}
