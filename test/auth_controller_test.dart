import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/features/auth/application/auth_controller.dart';
import 'package:visionguard/features/auth/data/auth_repository.dart';

import 'database_test.dart' show memoryDb;

/// Repository yang perilakunya diatur per test.
class _ScriptedRepository implements AuthRepository {
  _ScriptedRepository(this.onLogin);

  final Future<AppUser> Function() onLogin;
  bool logoutThrows = false;

  @override
  Future<AppUser> login(String email, String password) => onLogin();

  @override
  Future<AppUser> register(String name, String email, String password) => onLogin();

  @override
  Future<void> logout() async {
    if (logoutThrows) throw StateError('server mati');
  }

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<String> forgotPassword(String email) async => 'terkirim';

  @override
  Future<void> deleteAccount(String password) async {}
}

ProviderContainer _container(
  AuthRepository repo, {
  Duration deadline = const Duration(seconds: 5),
}) {
  final db = memoryDb();
  final c = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(repo),
    authDeadlineProvider.overrideWithValue(deadline),
  ]);
  addTearDown(() async {
    c.dispose();
    await db.close();
  });
  return c;
}

void main() {
  group('AuthController tidak pernah macet loading', () {
    test('sukses → isLoggedIn, isLoading false', () async {
      final c = _container(_ScriptedRepository(() async => const AppUser(name: 'Ani', email: 'ani@x.id')));

      expect(await c.read(authControllerProvider.notifier).login('ani@x.id', 'p'), isTrue);
      final s = c.read(authControllerProvider);
      expect(s.isLoggedIn, isTrue);
      expect(s.isLoading, isFalse);
      expect(s.userName, 'Ani');
    });

    test('AuthException → pesan dari repository', () async {
      final c = _container(_ScriptedRepository(() async => throw AuthException('Email atau kata sandi salah.')));

      expect(await c.read(authControllerProvider.notifier).login('a', 'b'), isFalse);
      final s = c.read(authControllerProvider);
      expect(s.isLoading, isFalse);
      expect(s.error, 'Email atau kata sandi salah.');
    });

    test('error lain (mis. PlatformException/TypeError) → isLoading false + pesan umum', () async {
      for (final error in <Object>[StateError('x'), const FormatException('y'), TypeError()]) {
        final c = _container(_ScriptedRepository(() async => throw error));

        expect(await c.read(authControllerProvider.notifier).login('a', 'b'), isFalse, reason: '$error');
        final s = c.read(authControllerProvider);
        expect(s.isLoading, isFalse, reason: '$error');
        expect(s.isLoggedIn, isFalse);
        expect(s.error, 'Terjadi kesalahan tak terduga. Coba lagi.');
      }
    });

    test('repository gagal dibuat (mis. konfigurasi salah) → isLoading false', () async {
      final c = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWith((ref) => throw const FormatException('base URL rusak')),
      ]);
      addTearDown(c.dispose);

      expect(await c.read(authControllerProvider.notifier).login('a', 'b'), isFalse);
      expect(c.read(authControllerProvider).isLoading, isFalse);
      expect(c.read(authControllerProvider).error, isNotNull);
    });

    test('proses menggantung → berhenti setelah batas waktu dengan pesan', () async {
      final c = _container(
        _ScriptedRepository(() => Completer<AppUser>().future),
        deadline: const Duration(milliseconds: 50),
      );

      final ok = await c.read(authControllerProvider.notifier).login('a', 'b').timeout(const Duration(seconds: 5));
      expect(ok, isFalse);
      final s = c.read(authControllerProvider);
      expect(s.isLoading, isFalse);
      expect(s.error, 'Server tidak merespons. Periksa koneksi lalu coba lagi.');
    });

    test('register memakai penanganan yang sama', () async {
      final c = _container(_ScriptedRepository(() async => throw StateError('x')));

      expect(await c.read(authControllerProvider.notifier).register('Ani', 'a', 'b'), isFalse);
      expect(c.read(authControllerProvider).isLoading, isFalse);
    });

    test('percobaan ulang menghapus error lama', () async {
      var fail = true;
      final c = _container(_ScriptedRepository(() async {
        if (fail) throw AuthException('salah');
        return const AppUser(name: 'Ani', email: 'ani@x.id');
      }));
      final auth = c.read(authControllerProvider.notifier);

      await auth.login('a', 'b');
      expect(c.read(authControllerProvider).error, 'salah');
      fail = false;
      expect(await auth.login('a', 'b'), isTrue);
      expect(c.read(authControllerProvider).error, isNull);
    });

    test('logout tetap mereset state walau repository melempar', () async {
      final repo = _ScriptedRepository(() async => const AppUser(name: 'Ani', email: 'ani@x.id'))..logoutThrows = true;
      final c = _container(repo);
      final auth = c.read(authControllerProvider.notifier);

      await auth.login('a', 'b');
      await auth.logout();
      expect(c.read(authControllerProvider).isLoggedIn, isFalse);
    });
  });
}
