import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';
import '../data/auth_repository.dart';
import '../data/session_store.dart';
import 'local_data_cleaner.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? userName;
  final String? email;
  final String? error;

  /// Apakah pengguna sudah menyetujui privasi & izin kamera (UC-06).
  /// Disimpan per akun di `settings` lokal.
  final bool privacyAccepted;

  /// Masuk dari sesi tersimpan tanpa verifikasi server (offline).
  final bool offline;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.userName,
    this.email,
    this.error,
    this.privacyAccepted = false,
    this.offline = false,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? userName,
    String? email,
    String? error,
    bool clearError = false,
    bool? privacyAccepted,
    bool? offline,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isLoading: isLoading ?? this.isLoading,
        userName: userName ?? this.userName,
        email: email ?? this.email,
        error: clearError ? null : (error ?? this.error),
        privacyAccepted: privacyAccepted ?? this.privacyAccepted,
        offline: offline ?? this.offline,
      );
}

/// Backend Laravel asli (bawaan) atau tiruan (`USE_REMOTE_API=false` & test).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiConstants.useRemoteApi
      ? ApiAuthRepository(ref.watch(apiClientProvider))
      : FakeAuthRepository(),
);

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Batas waktu total login/registrasi (dapat di-override di test).
final authDeadlineProvider = Provider<Duration>((ref) => ApiConstants.authDeadline);

/// Hasil aksi akun yang menampilkan pesan (lupa sandi, hapus akun).
typedef AuthActionResult = ({bool ok, String message});

/// Mengelola login, registrasi, auto-login, logout, lupa sandi, dan hapus akun
/// (UC-01..UC-05).
class AuthController extends Notifier<AuthState> {
  static const _timeoutMessage = 'Server tidak merespons. Periksa koneksi lalu coba lagi.';
  static const _unexpectedMessage = 'Terjadi kesalahan tak terduga. Coba lagi.';

  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  SessionStore get _session => ref.read(sessionStoreProvider);
  Duration get _deadline => ref.read(authDeadlineProvider);

  Future<bool> login(String email, String password) =>
      _authenticate((repo) => repo.login(email, password));

  Future<bool> register(String name, String email, String password) =>
      _authenticate((repo) => repo.register(name, email, password));

  /// Apa pun yang terjadi (error dari repository, kegagalan membuat provider,
  /// atau proses yang menggantung), `isLoading` selalu kembali `false` dan
  /// pengguna melihat pesan, sehingga spinner tidak berputar selamanya.
  Future<bool> _authenticate(Future<AppUser> Function(AuthRepository repo) action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await action(_repo).timeout(_deadline);
      await _signedIn(user, offline: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } on TimeoutException {
      state = state.copyWith(isLoading: false, error: _timeoutMessage);
    } catch (e, st) {
      // Jangan mencetak email/sandi; cukup jenis & pesan error.
      debugPrint('AuthController: ${e.runtimeType}: $e\n$st');
      state = state.copyWith(isLoading: false, error: _unexpectedMessage);
    }
    return false;
  }

  /// Auto-login saat aplikasi dibuka (token tersimpan → `GET /me`).
  /// Offline dengan sesi tersimpan → masuk memakai profil terakhir (§1.2 no. 5:
  /// pemantauan & Mode Timer tetap bisa dipakai offline).
  Future<bool> restoreSession() async {
    try {
      final user = await _repo.restoreSession().timeout(_deadline);
      if (user == null) {
        await _safe(_session.clearUser);
        return false;
      }
      final cached = await _safeValue(_session.cachedUser);
      await _signedIn(user.copyWith(deviceId: cached?.deviceId), offline: false);
      return true;
    } on AuthOfflineException {
      final cached = await _safeValue(_session.cachedUser);
      if (cached == null) return false;
      await _signedIn(cached, offline: true);
      return true;
    } catch (e) {
      debugPrint('AuthController.restoreSession: ${e.runtimeType}');
      final cached = await _safeValue(_session.cachedUser);
      if (cached == null) return false;
      await _signedIn(cached, offline: true);
      return true;
    }
  }

  Future<void> _signedIn(AppUser user, {required bool offline}) async {
    await _safe(() => _session.saveUser(user));
    final privacy = await _safeValue(() => _session.privacyAccepted(user.email)) ?? false;
    state = AuthState(
      isLoggedIn: true,
      userName: user.name,
      email: user.email,
      privacyAccepted: privacy,
      offline: offline,
    );
  }

  /// UC-06: persetujuan privasi disimpan per akun.
  void acceptPrivacy() {
    state = state.copyWith(privacyAccepted: true);
    final email = state.email;
    if (email != null) _safe(() => _session.setPrivacyAccepted(email));
  }

  /// UC-03: kirim tautan reset kata sandi.
  Future<AuthActionResult> forgotPassword(String email) async {
    try {
      final message = await _repo.forgotPassword(email).timeout(_deadline);
      return (ok: true, message: message);
    } on AuthException catch (e) {
      return (ok: false, message: e.message);
    } on TimeoutException {
      return (ok: false, message: _timeoutMessage);
    } catch (e) {
      debugPrint('AuthController.forgotPassword: ${e.runtimeType}');
      return (ok: false, message: _unexpectedMessage);
    }
  }

  /// UC-05: hapus akun di server, lalu hapus semua data lokal dan keluar.
  /// Pemanggil menghentikan pemantauan lebih dulu.
  Future<AuthActionResult> deleteAccount(String password) async {
    try {
      await _repo.deleteAccount(password).timeout(_deadline);
    } on AuthException catch (e) {
      return (ok: false, message: e.message);
    } on TimeoutException {
      return (ok: false, message: _timeoutMessage);
    } catch (e) {
      debugPrint('AuthController.deleteAccount: ${e.runtimeType}');
      return (ok: false, message: _unexpectedMessage);
    }
    await ref.read(localDataCleanerProvider).wipeAll();
    state = const AuthState();
    return (ok: true, message: 'Akun dan data pribadi telah dihapus.');
  }

  /// State langsung direset agar UI kembali ke login; pencabutan token
  /// berjalan di belakang dan tidak menahan UI walau offline.
  Future<void> logout() async {
    state = const AuthState();
    await _safe(_session.clearUser);
    ref.read(localDataCleanerProvider).resetInMemory();
    try {
      await _repo.logout();
    } catch (e) {
      debugPrint('AuthController: logout di server gagal (${e.runtimeType}).');
    }
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('AuthController: penyimpanan lokal gagal (${e.runtimeType}).');
    }
  }

  static Future<T?> _safeValue<T>(Future<T?> Function() f) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('AuthController: penyimpanan lokal gagal (${e.runtimeType}).');
      return null;
    }
  }
}
