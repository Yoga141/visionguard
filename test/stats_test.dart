import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/app/theme.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/features/monitoring/data/alert_repository.dart';
import 'package:visionguard/features/monitoring/data/metrics_repository.dart';
import 'package:visionguard/features/monitoring/data/session_repository.dart';
import 'package:visionguard/features/stats/application/stats_controller.dart';
import 'package:visionguard/features/stats/data/demo_data_seeder.dart';
import 'package:visionguard/features/stats/data/stats_repository.dart';
import 'package:visionguard/features/stats/presentation/statistics_page.dart';

import 'database_test.dart' show memoryDb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 2, 15, 30);
  late AppDatabase db;
  late FakeStatsRepository server;
  ProviderContainer container() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        statsRepositoryProvider.overrideWithValue(server),
        statsClockProvider.overrideWithValue(() => now),
      ]);

  setUp(() {
    db = memoryDb();
    server = FakeStatsRepository();
  });
  tearDown(() => db.close());

  /// Sesi AI [start] selama [minutes] menit + sampel per menit + pengingat.
  Future<int> addSession(DateTime start, int minutes,
      {double br = 12, double dist = 55, int score = 40}) async {
    final sessions = SessionRepository(db), metrics = MetricsRepository(db);
    final id = await sessions.start(SessionMode.ai, at: start);
    for (var m = 1; m <= minutes; m++) {
      await metrics.saveSample(MetricsSnapshot(
        sessionId: id,
        ts: start.add(Duration(minutes: m)),
        blinkRate: br,
        distanceCm: dist,
        fatigueScore: score,
        validRatioPct: 90,
      ));
    }
    await sessions.end(id, at: start.add(Duration(minutes: minutes)));
    return id;
  }

  group('Agregasi daily_summaries (DFD 6.1)', () {
    test('ringkasan hari ini dari metric_samples + alerts, lalu tersinkron', () async {
      final id = await addSession(DateTime(2026, 11, 2, 9), 30, br: 10, dist: 50, score: 50);
      await addSession(DateTime(2026, 11, 2, 13), 30, br: 14, dist: 60, score: 30);
      final alerts = AlertRepository(db);
      final t = DateTime(2026, 11, 2, 9, 20);
      await alerts.record(sessionId: id, type: AlertTypes.rule202020, action: AlertAction.followed, at: t);
      await alerts.record(sessionId: id, type: AlertTypes.rest, action: AlertAction.dismissed, at: t);
      await alerts.record(sessionId: id, type: AlertTypes.rule202020, action: AlertAction.snoozed, at: t);
      await alerts.record(sessionId: id, type: AlertTypes.distance, action: AlertAction.followed, at: t);

      final c = container();
      final data = await c.read(statsControllerProvider.future);
      final s = data.today!;
      expect(s.day, '2026-11-02');
      expect(s.screenMinutes, 60);
      expect(s.avgBlinkRate, closeTo(12, 1e-9));
      expect(s.avgDistanceCm, closeTo(55, 1e-9));
      expect(s.avgFatigueScore, closeTo(40, 1e-9));
      expect(s.alertsCount, 4);
      expect(s.breaksTaken, 1); // hanya istirahat/20-20-20 yang diikuti
      expect(data.breakReminders, 3);
      expect(data.breakCompliance, closeTo(1 / 3, 1e-9));

      // Tersinkron ke server tiruan → synced = true.
      expect(data.synced, isTrue);
      expect(await MetricsRepository(db).pendingSync(), isEmpty);
      expect((await server.range('2026-11-02', '2026-11-02')).single.screenMinutes, 60);
      c.dispose();
    });

    test('offline → synced tetap false, tren dari data lokal', () async {
      await addSession(DateTime(2026, 11, 1, 9), 20);
      await addSession(DateTime(2026, 11, 2, 9), 10);
      server.offline = true;
      final c = container();
      final data = await c.read(statsControllerProvider.future);
      expect(data.synced, isFalse);
      expect(StatsData.daysWithData(data.lastDays(7)), 2);
      final pending = await MetricsRepository(db).pendingSync();
      expect(pending.map((p) => p.day), unorderedEquals(['2026-11-01', '2026-11-02']));
      expect(pending.every((p) => !p.synced), isTrue);
      c.dispose();
    });

    test('sesi melewati tengah malam dihitung di dua hari', () async {
      await addSession(DateTime(2026, 10, 31, 23, 30), 60);
      final days = await MetricsRepository(db).activeDaysSince(DateTime(2026, 10, 25), now: now);
      expect(days, {'2026-10-31', '2026-11-01'});
      final c = container();
      final data = await c.read(statsControllerProvider.future);
      final byDay = {for (final p in data.trend) dayKey(p.day): p.summary};
      expect(byDay['2026-10-31']!.screenMinutes, 30);
      expect(byDay['2026-11-01']!.screenMinutes, 30);
      expect(data.today, isNull);
      c.dispose();
    });

    test('tanpa data: hari ini null, tren 30 titik kosong, tidak ada baris kosong dibuat', () async {
      final c = container();
      final data = await c.read(statsControllerProvider.future);
      expect(data.today, isNull);
      expect(data.trend, hasLength(30));
      expect(dayKey(data.trend.last.day), '2026-11-02');
      expect(StatsData.daysWithData(data.trend), 0);
      expect(await db.select(db.dailySummaries).get(), isEmpty);
      c.dispose();
    });

    test('data contoh 14 hari (debug) → 14 hari berdata termasuk hari ini', () async {
      final c = container();
      await c.read(statsControllerProvider.future);
      await c.read(statsControllerProvider.notifier).seedDemoData();
      final data = c.read(statsControllerProvider).requireValue;
      expect(StatsData.daysWithData(data.trend), 14);
      expect(StatsData.daysWithData(data.lastDays(7)), 7);
      expect(data.today, isNotNull);
      expect(data.today!.avgFatigueScore, inInclusiveRange(0, 100));
      expect(data.breakCompliance, isNotNull);
      c.dispose();
    });

    test('seeder deterministik dan tidak membuat sesi masa depan', () async {
      final early = DateTime(2026, 11, 2, 0, 10);
      await DemoDataSeeder(db).seed(days: 3, now: early);
      final sessions = await db.select(db.sessions).get();
      expect(sessions, isNotEmpty);
      for (final s in sessions) {
        expect(DateTime.parse(s.endedAt!).isAfter(early), isFalse);
      }
    });
  });

  group('StatisticsPage (S-08)', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      final c = container();
      await tester.runAsync(() => c.read(statsControllerProvider.future));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: AppTheme.light, home: const StatisticsPage()),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('tanpa data → pesan "Belum ada data hari ini" & "Data belum cukup"', (tester) async {
      final c = await pump(tester);
      expect(find.text('Belum ada data hari ini'), findsOneWidget);
      await tester.tap(find.text('Tren'));
      await tester.pumpAndSettle();
      expect(find.text('Data belum cukup (minimal 2 hari)'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('dengan data → ringkasan, kartu Saran AI, grafik 7 & 30 hari', (tester) async {
      await tester.runAsync(() => DemoDataSeeder(db).seed(days: 14, now: now));
      final c = await pump(tester);
      for (final t in [
        'Durasi layar', 'Rata-rata blink rate', 'Rata-rata jarak', 'Rata-rata skor', //
        'Jumlah pengingat', 'Kepatuhan istirahat', 'Saran AI', 'Saran umum, bukan diagnosis medis',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }

      await tester.tap(find.text('Tren'));
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsNWidgets(2));
      expect(find.byType(BarChart), findsOneWidget);

      await tester.tap(find.text('30 hari'));
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });
}
