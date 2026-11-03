import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/app/theme.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/features/calibration/application/calibration_controller.dart';
import 'package:visionguard/features/calibration/data/calibration_repository.dart';
import 'package:visionguard/features/credits/application/credit_controller.dart';
import 'package:visionguard/features/credits/data/credit_repository.dart';
import 'package:visionguard/features/credits/domain/credit_models.dart';
import 'package:visionguard/features/credits/presentation/credits_page.dart';
import 'package:visionguard/features/monitoring/application/monitoring_controller.dart';

import 'database_test.dart' show memoryDb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeCreditRepository — algoritma aktivasi §8.2', () {
    late DateTime now;
    late FakeCreditRepository repo;
    setUp(() {
      now = DateTime(2026, 11, 2, 9);
      repo = FakeCreditRepository(clock: () => now);
    });

    test('awal bulan: kuota 2, saldo 0, hari ini belum aktif', () async {
      final s = await repo.status();
      expect(s.freeQuotaRemaining, 2);
      expect(s.balance, 0);
      expect(s.todayActive, isFalse);
      expect(s.today, '2026-11-02');
    });

    test('kuota gratis dulu; hari yang sama tidak memotong dua kali', () async {
      final r1 = await repo.activateToday();
      expect(r1, isA<ActivationSuccess>());
      r1 as ActivationSuccess;
      expect(r1.source, DaySource.free);
      expect(r1.alreadyActive, isFalse);
      expect(r1.status.freeQuotaRemaining, 1);

      now = now.add(const Duration(hours: 5)); // jeda lalu lanjut di hari yang sama
      final r2 = await repo.activateToday() as ActivationSuccess;
      expect(r2.alreadyActive, isTrue);
      expect(r2.source, DaySource.free);
      expect(r2.status.freeQuotaRemaining, 1);
      expect(r2.status.todayActive, isTrue);
    });

    test('kuota habis → kredit (ledger usage −1); saldo 0 → 402', () async {
      for (var d = 2; d <= 3; d++) {
        now = DateTime(2026, 11, d, 9);
        expect((await repo.activateToday() as ActivationSuccess).source, DaySource.free);
      }

      now = DateTime(2026, 11, 4, 9);
      final insufficient = await repo.activateToday();
      expect(insufficient, isA<ActivationInsufficient>());
      expect(insufficient.status.todayActive, isFalse);
      expect(insufficient.status.freeQuotaRemaining, 0);

      repo.addDemoCredit(2);
      final r = await repo.activateToday() as ActivationSuccess;
      expect(r.source, DaySource.credit);
      expect(r.status.balance, 1);

      // Hari yang sama: tidak memotong lagi.
      final again = await repo.activateToday() as ActivationSuccess;
      expect(again.alreadyActive, isTrue);
      expect(again.status.balance, 1);

      final ledger = await repo.ledger();
      final usage = ledger.where((e) => e.reason == LedgerReason.usage).toList();
      expect(usage, hasLength(1));
      expect(usage.single.delta, -1);
      expect(usage.single.monitoringDayId, isNotNull);
      // Saldo = SUM(delta) ledger (§8.3).
      expect(ledger.fold<int>(0, (a, e) => a + e.delta), 1);
    });

    test('kuota gratis direset di bulan berikutnya', () async {
      for (var d = 2; d <= 3; d++) {
        now = DateTime(2026, 11, d, 9);
        await repo.activateToday();
      }
      expect((await repo.status()).freeQuotaRemaining, 0);
      now = DateTime(2026, 12, 1, 0, 5);
      expect((await repo.status()).freeQuotaRemaining, 2);
      expect((await repo.activateToday() as ActivationSuccess).source, DaySource.free);
    });

    test('data demo: saldo 4 dari ledger, riwayat order & mutasi, paket aktif saja', () async {
      final demo = FakeCreditRepository.demo(clock: () => now);
      final s = await demo.status();
      expect(s.balance, 4);
      expect(s.freeQuotaRemaining, 2);
      final orders = await demo.orders();
      expect(orders.map((o) => o.status), containsAll([OrderStatus.settlement, OrderStatus.expire]));
      expect((await demo.ledger()).map((e) => e.reason),
          containsAll([LedgerReason.purchase, LedgerReason.usage]));
      final packages = await demo.packages();
      expect(packages, isNotEmpty);
      expect(packages.every((p) => p.isActive), isTrue);
    });
  });

  group('MonitoringController memakai CreditRepository', () {
    late AppDatabase db;
    late FakeCreditRepository repo;
    late ProviderContainer c;

    setUp(() async {
      db = memoryDb();
      repo = FakeCreditRepository(clock: () => DateTime(2026, 11, 2, 9));
      c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        creditRepositoryProvider.overrideWithValue(repo),
      ]);
      await c.read(calibrationRepositoryProvider).save(
          cameraId: CameraSource.simulatedCameraId, earBaseline: 0.3, focalPx: 600);
      await c.read(calibrationControllerProvider.notifier).restoreSaved();
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('Mulai → Stop → Mulai di hari yang sama hanya memakai 1 kuota', () async {
      final m = c.read(monitoringControllerProvider.notifier);
      expect(await m.startAi(), StartAiOutcome.started);
      await m.stop();
      expect(await m.startAi(), StartAiOutcome.started);
      await m.stop();
      expect(repo.activationCalls, 2);
      final s = await repo.status();
      expect(s.freeQuotaRemaining, 1);
      expect(c.read(creditControllerProvider).status?.todayActive, isTrue);
    });

    test('kuota & kredit habis → insufficientCredit, kamera tidak menyala', () async {
      final c2 = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        creditRepositoryProvider.overrideWithValue(_ExhaustedRepo()),
      ]);
      await c2.read(calibrationControllerProvider.notifier).restoreSaved();
      final m = c2.read(monitoringControllerProvider.notifier);
      expect(await m.startAi(), StartAiOutcome.insufficientCredit);
      final st = c2.read(monitoringControllerProvider);
      expect(st.mode, MonitoringMode.idle);
      expect(st.starting, isFalse);
      expect(st.message, contains('Beli kredit'));
      c2.dispose();
    });

    test('server tak terjangkau → Mode Timer', () async {
      final c2 = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        creditRepositoryProvider.overrideWithValue(_OfflineRepo()),
      ]);
      await c2.read(calibrationControllerProvider.notifier).restoreSaved();
      final m = c2.read(monitoringControllerProvider.notifier);
      expect(await m.startAi(), StartAiOutcome.offlineTimerMode);
      expect(c2.read(monitoringControllerProvider).mode, MonitoringMode.timer);
      await m.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c2.dispose();
    });
  });

  group('CreditsPage (S-09)', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      final c = ProviderContainer(overrides: [
        creditRepositoryProvider
            .overrideWithValue(FakeCreditRepository.demo(clock: () => DateTime(2026, 11, 2, 9))),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: AppTheme.light, home: const CreditsPage()),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('kuota, saldo, status hari ini, paket & dialog Beli', (tester) async {
      final c = await pump(tester);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('belum aktif'), findsOneWidget);
      expect(find.text('Paket Hemat'), findsOneWidget);
      expect(find.text('Paket Lama'), findsNothing); // nonaktif
      expect(find.textContaining('Rp15.000'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Beli').first);
      await tester.pumpAndSettle();
      expect(find.text('Pembayaran Midtrans akan tersedia setelah backend siap.'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('riwayat transaksi & pemakaian kredit', (tester) async {
      final c = await pump(tester);
      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Berhasil'), findsOneWidget);
      expect(find.text('Kedaluwarsa'), findsOneWidget);
      expect(find.text('Pemakaian: Hari Pemantauan AI'), findsOneWidget);
      expect(find.text('Pembelian kredit'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });

  test('formatRupiah', () {
    expect(formatRupiah(15000), 'Rp15.000');
    expect(formatRupiah(1250000), 'Rp1.250.000');
    expect(formatRupiah(500), 'Rp500');
  });
}

/// Kuota gratis & saldo habis.
class _ExhaustedRepo extends FakeCreditRepository {
  @override
  Future<ActivationResult> activateToday() async => ActivationInsufficient(await status());
}

/// Server tidak terjangkau.
class _OfflineRepo extends FakeCreditRepository {
  @override
  Future<ActivationResult> activateToday() => Future.error(StateError('offline'));
}
