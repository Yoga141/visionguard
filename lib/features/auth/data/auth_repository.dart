/// Kontrak akses data akun. Implementasi asli nantinya memanggil REST API
/// Laravel + Sanctum (POST /api/login, /api/register).
abstract class AuthRepository {
  Future<AppUser> login(String email, String password);
  Future<AppUser> register(String name, String email, String password);
}

class AppUser {
  final String name;
  final String email;
  const AppUser({required this.name, required this.email});
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Repository tiruan untuk tahap progress 30% (backend belum dibangun).
/// Akun demo: demo@visionguard.id / password123
class FakeAuthRepository implements AuthRepository {
  final Map<String, ({String name, String password})> _users = {
    'demo@visionguard.id': (name: 'Pengguna Demo', password: 'password123'),
  };
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  @override
  Future<AppUser> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600)); // simulasi jaringan
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      throw AuthException('Terlalu banyak percobaan. Coba lagi dalam 5 menit.');
    }
    final u = _users[email.trim().toLowerCase()];
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
    return AppUser(name: u.name, email: email.trim().toLowerCase());
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw AuthException('Email sudah terdaftar. Silakan login atau reset kata sandi.');
    }
    _users[key] = (name: name.trim(), password: password);
    return AppUser(name: name.trim(), email: key);
  }
}
