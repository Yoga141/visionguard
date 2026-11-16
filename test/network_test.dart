import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/network/api_client.dart';
import 'package:visionguard/core/network/token_storage.dart';
import 'package:visionguard/features/auth/data/api_auth_repository.dart';
import 'package:visionguard/features/auth/data/auth_repository.dart';

/// Adapter HTTP palsu: mencatat request terakhir dan membalas [status] + [body].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, [this.body = const {}]);

  int status;
  Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient api, FakeAdapter adapter, InMemoryTokenStorage tokens}) fakeClient(
  int status, [
  Object body = const {},
  String? token,
]) {
  final adapter = FakeAdapter(status, body);
  final tokens = InMemoryTokenStorage(token);
  final dio = Dio()..httpClientAdapter = adapter;
  final api = ApiClient(tokenStorage: tokens, baseUrl: 'https://test/api', dio: dio);
  return (api: api, adapter: adapter, tokens: tokens);
}

void main() {
  group('ApiClient', () {
    test('menyisipkan token Sanctum jika tersimpan', () async {
      final c = fakeClient(200, {'ok': true}, 'abc');
      await c.api.get('/credits/status');
      expect(c.adapter.last!.headers['Authorization'], 'Bearer abc');
      expect(c.adapter.last!.uri.toString(), 'https://test/api/credits/status');
    });

    test('tanpa token tidak ada header Authorization', () async {
      final c = fakeClient(200);
      await c.api.get('/credits/status');
      expect(c.adapter.last!.headers.containsKey('Authorization'), isFalse);
    });

    final cases = <int, Matcher>{
      401: isA<UnauthorizedException>(),
      402: isA<PaymentRequiredException>(),
      403: isA<ForbiddenException>(),
      404: isA<NotFoundException>(),
      422: isA<ValidationException>(),
      500: isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
    };
    cases.forEach((code, matcher) {
      test('memetakan HTTP $code', () async {
        final c = fakeClient(code, {'message': 'pesan $code'});
        await expectLater(
          c.api.post('/x'),
          throwsA(allOf(matcher,
              isA<ApiException>().having((e) => e.message, 'message', 'pesan $code'))),
        );
      });
    });

    test('422 membawa error per field format Laravel', () async {
      final c = fakeClient(422, {
        'message': 'The given data was invalid.',
        'errors': {
          'email': ['Email sudah terdaftar.'],
        },
      });
      try {
        await c.api.post('/auth/register');
        fail('harus melempar');
      } on ValidationException catch (e) {
        expect(e.firstError('email'), 'Email sudah terdaftar.');
        expect(e.firstError('name'), isNull);
      }
    });

    test('tanpa respons dipetakan ke NetworkException', () {
      final e = ApiClient.mapDioException(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ));
      expect(e, isA<NetworkException>());
      expect(e.statusCode, isNull);
    });
  });

  group('ApiAuthRepository', () {
    test('login menyimpan token dan mengembalikan pengguna', () async {
      final c = fakeClient(200, {
        'token': 'tok-1',
        'user': {'id': 1, 'name': 'Ani', 'email': 'ani@x.id', 'role': 'user'},
      });
      final user = await ApiAuthRepository(c.api).login(' Ani@X.id ', 'rahasia');
      expect(user.name, 'Ani');
      expect(await c.tokens.read(), 'tok-1');
      final body = c.adapter.last!.data as Map;
      expect(body['email'], 'ani@x.id');
      expect(body.containsKey('platform'), isTrue);
    });

    test('login 401 → AuthException kredensial salah', () async {
      final c = fakeClient(401, {'message': 'Unauthenticated.'});
      await expectLater(
        ApiAuthRepository(c.api).login('a@b.id', 'salah'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', 'Email atau kata sandi salah.')),
      );
    });

    test('register 422 → pesan error email', () async {
      final c = fakeClient(422, {
        'message': 'invalid',
        'errors': {
          'email': ['Email sudah terdaftar.'],
        },
      });
      await expectLater(
        ApiAuthRepository(c.api).register('Ani', 'a@b.id', 'rahasia123'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Email sudah terdaftar.')),
      );
    });

    test('logout menghapus token lokal walau server gagal', () async {
      final c = fakeClient(500, {}, 'tok-1');
      await ApiAuthRepository(c.api).logout();
      expect(c.adapter.last!.path, '/auth/logout');
      expect(await c.tokens.read(), isNull);
    });

    test('token gagal disimpan → AuthException jelas, bukan error mentah', () async {
      final adapter = FakeAdapter(200, {
        'token': 'tok-1',
        'user': {'name': 'Ani', 'email': 'ani@x.id'},
      });
      final api = ApiClient(
        tokenStorage: _BrokenStorage(),
        baseUrl: 'https://test/api',
        dio: Dio()..httpClientAdapter = adapter,
        tokenReadTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        ApiAuthRepository(api).login('ani@x.id', 'rahasia'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', contains('sesi tidak dapat disimpan'))),
      );
    });

    test('respons login tanpa field user lengkap → AuthException', () async {
      final c = fakeClient(200, {'token': 'tok-1', 'user': {'name': 'Ani'}});
      await expectLater(
        ApiAuthRepository(c.api).login('ani@x.id', 'rahasia'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', 'Respons server tidak dikenali.')),
      );
      expect(await c.tokens.read(), isNull);
    });

    test('base URL tidak valid → AuthException berisi petunjuk API_BASE_URL', () async {
      final api = ApiClient(
        tokenStorage: InMemoryTokenStorage(),
        baseUrl: '[http://127.0.0.1:8000/api](http://127.0.0.1:8000/api)',
      );
      await expectLater(
        ApiAuthRepository(api).login('ani@x.id', 'rahasia'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('API_BASE_URL'))),
      );
    });
  });

  group('ApiClient tahan gangguan', () {
    test('isValidBaseUrl', () {
      expect(ApiClient.isValidBaseUrl('http://127.0.0.1:8000/api'), isTrue);
      expect(ApiClient.isValidBaseUrl('https://api.contoh.id/api'), isTrue);
      expect(ApiClient.isValidBaseUrl('[http://127.0.0.1:8000/api](http://127.0.0.1:8000/api)'), isFalse);
      expect(ApiClient.isValidBaseUrl('127.0.0.1:8000/api'), isFalse);
      expect(ApiClient.isValidBaseUrl(''), isFalse);
    });

    test('base URL tidak valid: konstruktor tidak melempar, request → NetworkException', () async {
      late ApiClient api;
      expect(
        () => api = ApiClient(tokenStorage: InMemoryTokenStorage(), baseUrl: '[http://x](http://x)'),
        returnsNormally,
      );
      await expectLater(api.post('/auth/login'), throwsA(isA<NetworkException>()));
    });

    test('baca token melempar → request tetap dikirim tanpa Authorization', () async {
      final adapter = FakeAdapter(200, {'ok': true});
      final api = ApiClient(
        tokenStorage: _BrokenStorage(),
        baseUrl: 'https://test/api',
        dio: Dio()..httpClientAdapter = adapter,
      );
      await api.get('/credits/status');
      expect(adapter.last, isNotNull);
      expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
    });

    test('baca token menggantung → request tetap dikirim setelah batas waktu', () async {
      final adapter = FakeAdapter(200, {'ok': true});
      final api = ApiClient(
        tokenStorage: _HangingStorage(),
        baseUrl: 'https://test/api',
        dio: Dio()..httpClientAdapter = adapter,
        tokenReadTimeout: const Duration(milliseconds: 50),
      );
      final res = await api.get('/credits/status').timeout(const Duration(seconds: 5));
      expect(res['ok'], isTrue);
      expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
    });
  });
}

/// Penyimpanan aman yang selalu gagal (mis. Credential Locker/Keystore error).
class _BrokenStorage implements TokenStorage {
  @override
  Future<String?> read() async => throw Exception('secure storage gagal');

  @override
  Future<void> write(String token) async => throw Exception('secure storage gagal');

  @override
  Future<void> delete() async => throw Exception('secure storage gagal');
}

/// Penyimpanan aman yang tidak pernah merespons.
class _HangingStorage implements TokenStorage {
  @override
  Future<String?> read() => Completer<String?>().future;

  @override
  Future<void> write(String token) => Completer<void>().future;

  @override
  Future<void> delete() => Completer<void>().future;
}
