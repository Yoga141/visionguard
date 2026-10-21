import 'package:firebase_auth/firebase_auth.dart';

/// Service autentikasi menggunakan Firebase Auth (email & password).
///
/// Menggantikan [FakeAuthRepository] untuk lingkungan produksi.
/// Seluruh operasi melempar [FirebaseAuthException] yang berisi pesan
/// ramah-pengguna dalam Bahasa Indonesia.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Pengguna yang sedang login, atau `null` jika belum terautentikasi.
  User? get currentUser => _auth.currentUser;

  /// Stream perubahan status autentikasi (untuk reactive listening).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Login dengan email dan password.
  ///
  /// Melempar [FirebaseAuthException] jika gagal.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(_mapErrorCode(e.code));
    }
  }

  /// Mendaftar akun baru dengan email dan password.
  ///
  /// Setelah berhasil, displayName pengguna diperbarui dengan [name].
  /// Melempar [FirebaseAuthException] jika gagal.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Simpan nama tampilan pengguna.
      await credential.user!.updateDisplayName(name.trim());
      await credential.user!.reload();
      return _auth.currentUser!;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(_mapErrorCode(e.code));
    }
  }

  /// Logout dari sesi saat ini.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Menerjemahkan kode error Firebase Auth ke pesan Bahasa Indonesia.
  static String _mapErrorCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Akun dengan email ini tidak ditemukan.';
      case 'wrong-password':
        return 'Kata sandi salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan login atau reset kata sandi.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah (minimal 6 karakter).';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi dalam beberapa menit.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan oleh administrator.';
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      default:
        return 'Terjadi kesalahan autentikasi ($code).';
    }
  }
}

/// Exception khusus untuk error autentikasi Firebase.
class FirebaseAuthException implements Exception {
  final String message;
  const FirebaseAuthException(this.message);

  @override
  String toString() => message;
}
