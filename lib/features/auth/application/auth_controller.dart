import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';
import '../data/auth_repository.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? userName;
  final String? email;
  final String? error;

  /// Apakah pengguna sudah menyetujui privasi & izin kamera (UC-06).
  final bool privacyAccepted;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.userName,
    this.email,
    this.error,
    this.privacyAccepted = false,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? userName,
    String? email,
    String? error,
    bool clearError = false,
    bool? privacyAccepted,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isLoading: isLoading ?? this.isLoading,
        userName: userName ?? this.userName,
        email: email ?? this.email,
        error: clearError ? null : (error ?? this.error),
        privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      );
}

/// Beralih ke REST API dengan `ApiConstants.useRemoteApi` (default: tiruan).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiConstants.useRemoteApi
      ? ApiAuthRepository(ref.watch(apiClientProvider))
      : FakeAuthRepository(),
);

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Mengelola login, registrasi, dan logout (UC-01, UC-02, UC-04).
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.login(email, password);
      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        userName: user.name,
        email: user.email,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.register(name, email, password);
      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        userName: user.name,
        email: user.email,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  void acceptPrivacy() => state = state.copyWith(privacyAccepted: true);

  /// State langsung direset agar UI kembali ke login; pencabutan token
  /// berjalan di belakang dan tidak menahan UI walau offline.
  Future<void> logout() async {
    final repo = _repo;
    state = const AuthState();
    await repo.logout();
  }
}
