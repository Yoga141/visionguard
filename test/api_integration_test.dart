import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/core/network/api_client.dart';
import 'package:visionguard/core/network/token_storage.dart';
import 'package:visionguard/features/ai_assistant/data/ai_advice_repository.dart';
import 'package:visionguard/features/ai_assistant/data/api_ai_advice_repository.dart';
import 'package:visionguard/features/auth/application/auth_controller.dart';
import 'package:visionguard/features/auth/data/api_auth_repository.dart';
import 'package:visionguard/features/auth/data/auth_repository.dart';
import 'package:visionguard/features/auth/data/session_store.dart';
import 'package:visionguard/features/credits/data/api_credit_repository.dart';
import 'package:visionguard/features/credits/domain/credit_models.dart';
import 'package:visionguard/features/settings/data/settings_repository.dart';
import 'package:visionguard/features/stats/application/sync_service.dart';
import 'package:visionguard/features/stats/data/api_stats_repository.dart';
import 'package:visionguard/features/stats/data/stats_repository.dart';

import 'database_test.dart' show memoryDb;

/// Satu balasan tiruan.
typedef Reply = ({int status, Object body});

/// Adapter HTTP tiruan berbasis rute "METHOD /path" yang mencatat semua request.
/// Rute tanpa balasan → `DioException.connectionError` (meniru offline).
class RouteAdapter implements HttpClientAdapter {
  RouteAdapter(this.routes);

  final Map<String, Reply> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = routes['${options.method} ${options.path}'];
    if (reply == null) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(jsonEncode(reply.body), reply.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient api, RouteAdapter http, InMemoryTokenStorage tokens}) client(
  Map<String, Reply> routes, {
  String? token,
}) {
  final http = RouteAdapter(routes);
  final tokens = InMemoryTokenStorage(token);
  final api = ApiClient(
    tokenStorage: tokens,
    baseUrl: 'http://127.0.0.1:8000/api',
    dio: Dio()..httpClientAdapter = http,
  );
  return (api: api, http: http, tokens: tokens);
}

const _user = {'id': 2, 'name': 'Demo', 'email': 'demo@visionguard.id', 'role': 'user', 'timezone': 'Asia/Jakarta'};

Map<String, Object?> _status({int balance = 4, int free = 1, bool active = true, String? source = 'free'}) => {
      'today': '2026-11-16',
      'timezone': 'Asia/Jakarta',
      'today_active': active,
      'today_source': source,
      'free_quota_remaining': free,
      'free_quota_per_month': 2,
      'credit_balance': balance,
      'updated_at': '2026-11-16T03:00:00+00:00',
    };

Map<String, Object?> _order({String status = 'pending'}) => {
      'id': 3,
      'order_code': 'VG-261116100500-AB12CD',
      'package_id': 1,
      'package_name': 'Paket Hemat',
      'credits': 5,
      'amount_idr': 15000,
      'status': status,
      'payment_type': status == 'settlement' ? 'qris' : null,
      'paid_at': status == 'settlement' ? '2026-11-16T03:10:00+00:00' : null,
      'created_at': '2026-11-16T03:05:00+00:00',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiAuthRepository (Tahap C)', () {
    test('login mengembalikan device_id dari server', () async {
      final c = client({
        'POST /auth/login': (status: 200, body: {'token': 't1', 'device_id': 7, 'user': _user}),
      });
      final u = await ApiAuthRepository(c.api).login('demo@visionguard.id', 'password123');
      expect(u.deviceId, 7);
      expect(u.id, 2);
      expect(await c.tokens.read(), 't1');
    });

    test('auto-login: tanpa token → null tanpa request', () async {
      final c = client({});
      expect(await ApiAuthRepository(c.api).restoreSession(), isNull);
      expect(c.http.requests, isEmpty);
    });

    test('auto-login: token + GET /me 200 → pengguna', () async {
      final c = client({'GET /me': (status: 200, body: {'user': _user})}, token: 't1');
      final u = await ApiAuthRepository(c.api).restoreSession();
      expect(u!.email, 'demo@visionguard.id');
      expect(c.http.requests.single.headers['Authorization'], 'Bearer t1');
    });

    test('auto-login: 401 → token dihapus, null', () async {
      final c = client({'GET /me': (status: 401, body: {'message': 'Unauthenticated.'})}, token: 't1');
      expect(await ApiAuthRepository(c.api).restoreSession(), isNull);
      expect(await c.tokens.read(), isNull);
    });

    test('auto-login: offline → AuthOfflineException, token tetap', () async {
      final c = client({}, token: 't1');
      await expectLater(ApiAuthRepository(c.api).restoreSession(), throwsA(isA<AuthOfflineException>()));
      expect(await c.tokens.read(), 't1');
    });

    test('lupa sandi: 200 pesan server, 404, 429', () async {
      final ok = client({
        'POST /auth/forgot-password': (status: 200, body: {'message': 'Tautan terkirim. Berlaku 60 menit.'}),
      });
      expect(await ApiAuthRepository(ok.api).forgotPassword(' Demo@VisionGuard.id '), 'Tautan terkirim. Berlaku 60 menit.');
      expect((ok.http.requests.single.data as Map)['email'], 'demo@visionguard.id');

      final missing = client({'POST /auth/forgot-password': (status: 404, body: {'message': 'Email tidak terdaftar.'})});
      await expectLater(ApiAuthRepository(missing.api).forgotPassword('x@y.id'),
          throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Email tidak terdaftar.')));

      final busy = client({'POST /auth/forgot-password': (status: 429, body: {'message': 'Too Many Attempts.'})});
      await expectLater(ApiAuthRepository(busy.api).forgotPassword('x@y.id'),
          throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('Tunggu sebentar'))));
    });

    test('hapus akun: 200 → DELETE /me dengan sandi, token dihapus; 403 → pesan', () async {
      final c = client({'DELETE /me': (status: 200, body: {'message': 'ok'})}, token: 't1');
      await ApiAuthRepository(c.api).deleteAccount('password123');
      expect(c.http.requests.single.method, 'DELETE');
      expect((c.http.requests.single.data as Map)['password'], 'password123');
      expect(await c.tokens.read(), isNull);

      final wrong = client({'DELETE /me': (status: 403, body: {'message': 'Kata sandi salah.'})}, token: 't1');
      await expectLater(ApiAuthRepository(wrong.api).deleteAccount('salah'),
          throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Kata sandi salah. Akun tidak dihapus.')));
      expect(await wrong.tokens.read(), 't1');
    });
  });

  group('ApiCreditRepository', () {
    test('status, paket, riwayat (satu request history untuk orders + ledger)', () async {
      final c = client({
        'GET /credits/status': (status: 200, body: _status()),
        'GET /credit-packages': (
          status: 200,
          body: {
            'packages': [
              {'id': 1, 'name': 'Paket Hemat', 'credits': 5, 'price_idr': 15000, 'is_active': true},
            ],
          }
        ),
        'GET /credits/history': (
          status: 200,
          body: {
            'credit_balance': 4,
            'orders': [_order(status: 'settlement')],
            'ledger': [
              {'id': 9, 'delta': -1, 'reason': 'usage', 'monitoring_day_id': 21, 'created_at': '2026-11-16T03:00:00+00:00'},
              {'id': 8, 'delta': 5, 'reason': 'purchase', 'order_id': 3, 'created_at': '2026-11-16T02:10:00+00:00'},
            ],
          }
        ),
      });
      final repo = ApiCreditRepository(c.api, deviceId: () async => 7);

      final s = await repo.status();
      expect((s.today, s.balance, s.freeQuotaRemaining, s.todayActive, s.todaySource),
          ('2026-11-16', 4, 1, true, DaySource.free));
      expect((await repo.packages()).single.priceIdr, 15000);

      final results = await Future.wait([repo.orders(), repo.ledger()]);
      final orders = results[0] as List<CreditOrder>;
      final ledger = results[1] as List<LedgerEntry>;
      expect(orders.single.status, OrderStatus.settlement);
      expect(orders.single.paymentType, 'qris');
      expect(ledger.map((e) => e.reason), [LedgerReason.usage, LedgerReason.purchase]);
      expect(c.http.requests.where((r) => r.path == '/credits/history'), hasLength(1));
    });

    test('aktivasi 200 mengirim device_id; 402 → ActivationInsufficient + status', () async {
      final ok = client({
        'POST /monitoring-days/activate': (
          status: 200,
          body: {..._status(balance: 3, free: 0, source: 'credit'), 'source': 'credit', 'already_active': false}
        ),
      });
      final r = await ApiCreditRepository(ok.api, deviceId: () async => 7).activateToday();
      expect(r, isA<ActivationSuccess>());
      expect((r as ActivationSuccess).source, DaySource.credit);
      expect(r.status.balance, 3);
      expect((ok.http.requests.single.data as Map)['device_id'], 7);

      final broke = client({
        'POST /monitoring-days/activate': (
          status: 402,
          body: {'message': 'Kredit tidak cukup.', ..._status(balance: 0, free: 0, active: false, source: null)}
        ),
      });
      final r2 = await ApiCreditRepository(broke.api, deviceId: () async => null).activateToday();
      expect(r2, isA<ActivationInsufficient>());
      expect(r2.status.balance, 0);
      expect(r2.status.todayActive, isFalse);
      expect(broke.http.requests.single.data, isEmpty); // tanpa device_id
    });

    test('aktivasi offline melempar (pemanggil beralih ke Mode Timer)', () async {
      final c = client({});
      await expectLater(ApiCreditRepository(c.api, deviceId: () async => 7).activateToday(),
          throwsA(isA<NetworkException>()));
    });

    test('POST /orders → CheckoutSession; GET /orders/{code} → status + saldo', () async {
      final c = client({
        'POST /orders': (
          status: 201,
          body: {
            'order_code': 'VG-261116100500-AB12CD',
            'snap_token': 'tok',
            'redirect_url': 'https://app.sandbox.midtrans.com/snap/v4/redirection/tok',
            'payment_mode': 'midtrans',
            'order': _order(),
          }
        ),
        'GET /orders/VG-261116100500-AB12CD': (status: 200, body: {'order': _order(status: 'settlement'), 'credit_balance': 9}),
      });
      final repo = ApiCreditRepository(c.api, deviceId: () async => 7);

      final checkout = await repo.createOrder(1);
      expect(checkout.redirectUrl, startsWith('https://app.sandbox.midtrans.com/'));
      expect(checkout.order.status, OrderStatus.pending);
      expect((c.http.requests.first.data as Map)['package_id'], 1);

      final check = await repo.orderStatus(checkout.orderCode);
      expect(check.order.status, OrderStatus.settlement);
      expect(check.balance, 9);
    });

    test('POST /orders 422 paket nonaktif dilempar sebagai ValidationException', () async {
      final c = client({
        'POST /orders': (
          status: 422,
          body: {
            'message': 'Paket kredit tidak tersedia.',
            'errors': {
              'package_id': ['Paket kredit tidak tersedia.'],
            },
          }
        ),
      });
      await expectLater(ApiCreditRepository(c.api, deviceId: () async => 7).createOrder(4),
          throwsA(isA<ValidationException>()));
    });
  });

  group('ApiStatsRepository', () {
    DailySummary summary(String day) => DailySummary(
          day: day,
          screenMinutes: 60,
          avgBlinkRate: 12.5,
          avgDistanceCm: null,
          avgFatigueScore: 30,
          alertsCount: 2,
          breaksTaken: 1,
          synced: false,
        );

    test('upload batch maks. 31 hari per request dengan device_id', () async {
      final c = client({'POST /stats/daily': (status: 200, body: {'message': 'ok'})});
      final days = [for (var i = 1; i <= 40; i++) summary('2026-10-${(i % 28 + 1).toString().padLeft(2, '0')}')];
      await ApiStatsRepository(c.api, deviceId: () async => 7).uploadDaily(days);

      expect(c.http.requests, hasLength(2));
      final first = c.http.requests.first.data as Map;
      expect(first['device_id'], 7);
      expect((first['summaries'] as List), hasLength(31));
      expect((first['summaries'] as List).first, containsPair('avg_distance_cm', null));
      expect(((c.http.requests.last.data as Map)['summaries'] as List), hasLength(9));
    });

    test('tanpa device_id → gagal (data tetap lokal), tanpa request', () async {
      final c = client({});
      await expectLater(ApiStatsRepository(c.api, deviceId: () async => null).uploadDaily([summary('2026-11-16')]),
          throwsA(isA<ApiException>()));
      expect(c.http.requests, isEmpty);
    });

    test('range memilih range=7/30 dan menyaring rentang', () async {
      final c = client({
        'GET /stats': (
          status: 200,
          body: {
            'range': 30,
            'days': [
              {'day': '2026-10-01', 'screen_minutes': 10, 'alerts_count': 0, 'breaks_taken': 0},
              {'day': '2026-11-16', 'screen_minutes': 120, 'avg_blink_rate': 12, 'alerts_count': 3, 'breaks_taken': 2},
            ],
          }
        ),
      });
      final repo = ApiStatsRepository(c.api, deviceId: () async => 7);

      final rows = await repo.range('2026-10-18', '2026-11-16');
      expect(c.http.requests.single.queryParameters['range'], 30);
      expect(rows.single.day, '2026-11-16');
      expect(rows.single.avgBlinkRate, 12.0);
      expect(rows.single.synced, isTrue);

      await repo.range('2026-11-10', '2026-11-16');
      expect(c.http.requests.last.queryParameters['range'], 7);
    });
  });

  group('Saran AI lewat POST /ai/advice', () {
    const metrics = AdviceMetrics(fatigueScore: 45, blinkRate: 9.5);

    test('200 → saran server; 429/offline → saran statis', () async {
      final ok = client({'POST /ai/advice': (status: 200, body: {'advice': 'Kedipkan mata 10 kali.'})});
      expect(await ApiAiAdviceRepository(ok.api).getAdvice(metrics), 'Kedipkan mata 10 kali.');
      expect((ok.http.requests.single.data as Map)['fatigue_score'], 45);

      final limited = client({'POST /ai/advice': (status: 429, body: {'message': 'Batas pemakaian.'})});
      expect(await ApiAiAdviceRepository(limited.api).getAdvice(metrics), StaticAdvice.forMetrics(metrics));
      expect(await ApiAiAdviceRepository(client({}).api).getAdvice(metrics), StaticAdvice.forMetrics(metrics));
    });
  });

  group('friendlyErrorMessage (poin 8)', () {
    ApiException http(int code, [Object? body]) => ApiClient.mapDioException(DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: code, data: body),
        ));

    test('pesan per kode HTTP', () {
      expect(friendlyErrorMessage(http(401, {'message': 'Unauthenticated.'})), 'Sesi Anda berakhir. Silakan masuk lagi.');
      expect(friendlyErrorMessage(http(402, {'message': 'Kredit tidak cukup. Beli kredit atau gunakan Mode Timer.'})),
          'Kredit tidak cukup. Beli kredit atau gunakan Mode Timer.');
      expect(friendlyErrorMessage(http(403, {'message': 'Kata sandi salah. Akun tidak dihapus.'})),
          'Kata sandi salah. Akun tidak dihapus.');
      expect(friendlyErrorMessage(http(404, {'message': 'No query results for model.'})), 'Data tidak ditemukan.');
      expect(
          friendlyErrorMessage(http(422, {
            'message': 'The given data was invalid.',
            'errors': {
              'email': ['Email sudah terdaftar.'],
            },
          })),
          'Email sudah terdaftar.');
      expect(friendlyErrorMessage(http(500, {'message': 'Server Error'})), 'Server sedang bermasalah. Coba lagi nanti.');
      expect(friendlyErrorMessage(http(403)), 'Verifikasi gagal.'); // tanpa body: pesan bawaan klien
    });

    test('offline & error non-API', () {
      final offline = ApiClient.mapDioException(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ));
      expect(friendlyErrorMessage(offline), 'Tidak dapat terhubung ke server. Periksa koneksi internet.');
      expect(friendlyErrorMessage(StateError('x')), 'Terjadi kesalahan tak terduga. Coba lagi.');
    });
  });

  group('AuthController + data lokal', () {
    late AppDatabase db;
    late FakeAuthRepository repo;
    late ProviderContainer c;

    setUp(() {
      db = memoryDb();
      repo = FakeAuthRepository();
      c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(repo),
      ]);
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    AuthController auth() => c.read(authControllerProvider.notifier);

    test('persetujuan privasi disimpan per akun', () async {
      await auth().login('demo@visionguard.id', 'password123');
      expect(c.read(authControllerProvider).privacyAccepted, isFalse);
      auth().acceptPrivacy();
      await Future<void>.delayed(Duration.zero);
      await auth().logout();

      await auth().register('Ani', 'ani@x.id', 'rahasia123');
      expect(c.read(authControllerProvider).privacyAccepted, isFalse, reason: 'akun lain belum setuju');
      await auth().logout();

      await auth().login('demo@visionguard.id', 'password123');
      expect(c.read(authControllerProvider).privacyAccepted, isTrue);
    });

    test('auto-login: sesi tersimpan → masuk; offline → profil tersimpan', () async {
      expect(await auth().restoreSession(), isFalse);

      await auth().login('demo@visionguard.id', 'password123');
      expect(await c.read(sessionStoreProvider).deviceId(), 1);
      expect(await auth().restoreSession(), isTrue);
      expect(c.read(authControllerProvider).offline, isFalse);

      repo.offline = true;
      expect(await auth().restoreSession(), isTrue);
      expect(c.read(authControllerProvider).offline, isTrue);
      expect(c.read(authControllerProvider).email, 'demo@visionguard.id');
    });

    test('logout menghapus profil tersimpan → auto-login berikutnya gagal', () async {
      await auth().login('demo@visionguard.id', 'password123');
      await auth().logout();
      expect(await c.read(sessionStoreProvider).cachedUser(), isNull);
      repo.offline = true;
      expect(await auth().restoreSession(), isFalse);
    });

    test('hapus akun: sandi salah → data tetap; benar → semua tabel lokal kosong', () async {
      await auth().login('demo@visionguard.id', 'password123');
      final settings = SettingsRepository(db);
      await settings.set('sensitivity', 'tinggi');
      await db.into(db.dailySummaries).insert(DailySummariesCompanion.insert(
            day: '2026-11-16', screenMinutes: 60, alertsCount: 1, breaksTaken: 1));
      await db.into(db.calibrations).insert(CalibrationsCompanion.insert(
            cameraId: 'cam', earBaseline: 0.3, focalPx: 600, createdAt: '2026-11-16T00:00:00.000Z'));

      final wrong = await auth().deleteAccount('salah');
      expect(wrong.ok, isFalse);
      expect(wrong.message, 'Kata sandi salah. Akun tidak dihapus.');
      expect(await db.select(db.dailySummaries).get(), isNotEmpty);

      final ok = await auth().deleteAccount('password123');
      expect(ok.ok, isTrue);
      expect(c.read(authControllerProvider).isLoggedIn, isFalse);
      expect(await db.select(db.dailySummaries).get(), isEmpty);
      expect(await db.select(db.calibrations).get(), isEmpty);
      expect(await settings.all(), isEmpty);

      // Akun sudah tidak ada di server tiruan.
      expect(await auth().login('demo@visionguard.id', 'password123'), isFalse);
    });

    test('lupa sandi: email dikenal → ok; tidak dikenal → pesan', () async {
      expect((await auth().forgotPassword('demo@visionguard.id')).ok, isTrue);
      final r = await auth().forgotPassword('x@y.id');
      expect(r.ok, isFalse);
      expect(r.message, 'Email tidak terdaftar.');
    });
  });

  group('SyncService', () {
    test('kirim ringkasan pending lalu tandai synced; gagal → tetap pending', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final server = FakeStatsRepository();
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        statsRepositoryProvider.overrideWithValue(server),
      ]);
      addTearDown(c.dispose);
      await db.into(db.dailySummaries).insert(DailySummariesCompanion.insert(
            day: '2026-11-15', screenMinutes: 60, alertsCount: 1, breaksTaken: 1));
      await db.into(db.dailySummaries).insert(DailySummariesCompanion.insert(
            day: '2026-11-16', screenMinutes: 30, alertsCount: 0, breaksTaken: 0, synced: const Value(true)));

      server.offline = true;
      expect(await c.read(syncServiceProvider).syncPending(), isFalse);
      expect((await db.select(db.dailySummaries).get()).where((d) => !d.synced), hasLength(1));

      server.offline = false;
      expect(await c.read(syncServiceProvider).syncPending(), isTrue);
      expect(server.uploadCalls, 1);
      expect((await db.select(db.dailySummaries).get()).every((d) => d.synced), isTrue);

      // Tidak ada yang tertunda → tidak ada upload baru.
      expect(await c.read(syncServiceProvider).syncPending(), isTrue);
      expect(server.uploadCalls, 1);
    });
  });
}
