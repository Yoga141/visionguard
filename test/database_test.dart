import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/features/calibration/data/calibration_repository.dart';
import 'package:visionguard/features/monitoring/data/alert_repository.dart';
import 'package:visionguard/features/monitoring/data/metrics_repository.dart';
import 'package:visionguard/features/monitoring/data/session_repository.dart';
import 'package:visionguard/features/settings/data/settings_repository.dart';

/// Database SQLite in-memory untuk test.
AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('Skema §12.3', () {
    Future<List<String>> columns(String table) async => [
          for (final r in await db.customSelect('PRAGMA table_info($table)').get())
            r.read<String>('name'),
        ];

    test('6 tabel dengan kolom persis sesuai DOCS_SPEC', () async {
      expect(await columns('calibrations'),
          ['id', 'camera_id', 'ear_baseline', 'focal_px', 'created_at']);
      expect(await columns('sessions'), ['id', 'mode', 'started_at', 'ended_at']);
      expect(await columns('metric_samples'), [
        'id', 'session_id', 'ts', 'blink_rate', 'perclos', 'distance_cm', //
        'fatigue_score', 'valid_ratio_pct',
      ]);
      expect(await columns('alerts'), ['id', 'session_id', 'ts', 'type', 'action']);
      expect(await columns('daily_summaries'), [
        'day', 'screen_minutes', 'avg_blink_rate', 'avg_distance_cm', //
        'avg_fatigue_score', 'alerts_count', 'breaks_taken', 'synced',
      ]);
      expect(await columns('settings'), ['key', 'value']);
    });

    test('tidak ada kolom BLOB (frame/gambar tidak bisa disimpan)', () async {
      for (final t in db.allTables) {
        final info = await db.customSelect('PRAGMA table_info(${t.actualTableName})').get();
        expect(info.map((r) => r.read<String>('type')), isNot(contains('BLOB')),
            reason: t.actualTableName);
      }
    });

    test('foreign key aktif: sampel tanpa sesi ditolak', () async {
      await expectLater(
        MetricsRepository(db).saveSample(
            MetricsSnapshot(sessionId: 999, ts: DateTime.now(), validRatioPct: 100)),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('CalibrationRepository', () {
    test('mengambil kalibrasi terbaru per camera_id (KLB-04)', () async {
      final repo = CalibrationRepository(db);
      await repo.save(cameraId: 'cam-A', earBaseline: 0.30, focalPx: 600, at: DateTime(2026, 10, 1));
      await repo.save(cameraId: 'cam-A', earBaseline: 0.28, focalPx: 610, at: DateTime(2026, 10, 2));
      await repo.save(cameraId: 'cam-B', earBaseline: 0.25, focalPx: 500, at: DateTime(2026, 10, 3));

      final a = await repo.latestFor('cam-A');
      expect(a!.earBaseline, 0.28);
      expect(a.focalPx, 610);
      expect((await repo.latestFor('cam-B'))!.earBaseline, 0.25);
      expect(await repo.latestFor('cam-C'), isNull);
    });
  });

  group('SessionRepository', () {
    test('start → ended_at kosong; end mengisi sekali saja', () async {
      final repo = SessionRepository(db);
      final id = await repo.start(SessionMode.timer, at: DateTime.utc(2026, 10, 30, 8));
      var s = await repo.byId(id);
      expect(s!.mode, SessionMode.timer);
      expect(s.startedAt, '2026-10-30T08:00:00.000Z');
      expect(s.endedAt, isNull);

      await repo.end(id, at: DateTime.utc(2026, 10, 30, 9));
      await repo.end(id, at: DateTime.utc(2026, 10, 30, 10));
      s = await repo.byId(id);
      expect(s!.endedAt, '2026-10-30T09:00:00.000Z');
    });

    test('mode disimpan sebagai teks ai/timer/check', () async {
      final repo = SessionRepository(db);
      for (final m in SessionMode.values) {
        await repo.start(m);
      }
      final rows = await db.customSelect('SELECT mode FROM sessions ORDER BY id').get();
      expect(rows.map((r) => r.read<String>('mode')), ['ai', 'timer', 'check']);
    });

    test('closeDangling memakai waktu sampel terakhir atau started_at', () async {
      final sessions = SessionRepository(db);
      final metrics = MetricsRepository(db);
      final withSample = await sessions.start(SessionMode.ai, at: DateTime.utc(2026, 10, 30, 8));
      await metrics.saveSample(MetricsSnapshot(
          sessionId: withSample, ts: DateTime.utc(2026, 10, 30, 8, 5), validRatioPct: 90));
      final empty = await sessions.start(SessionMode.timer, at: DateTime.utc(2026, 10, 30, 9));

      expect(await sessions.closeDangling(), 2);
      expect((await sessions.byId(withSample))!.endedAt, '2026-10-30T08:05:00.000Z');
      expect((await sessions.byId(empty))!.endedAt, '2026-10-30T09:00:00.000Z');
      expect(await sessions.closeDangling(), 0);
    });
  });

  group('AlertRepository', () {
    test('mencatat pengingat dan respons pengguna', () async {
      final sid = await SessionRepository(db).start(SessionMode.ai);
      final repo = AlertRepository(db);
      await repo.record(
          sessionId: sid, type: AlertTypes.blink, action: AlertAction.snoozed, at: DateTime(2026, 10, 30, 9));
      await repo.record(
          sessionId: sid, type: AlertTypes.rest, action: AlertAction.followed, at: DateTime(2026, 10, 30, 8));

      final list = await repo.forSession(sid);
      expect(list.map((a) => a.type), [AlertTypes.rest, AlertTypes.blink]);
      expect(list.first.action, AlertAction.followed);
      final raw = await db.customSelect('SELECT action FROM alerts ORDER BY ts').get();
      expect(raw.map((r) => r.read<String>('action')), ['followed', 'snoozed']);
    });
  });

  group('MetricsRepository', () {
    test('saveSample menyimpan angka per menit', () async {
      final sid = await SessionRepository(db).start(SessionMode.ai);
      final repo = MetricsRepository(db);
      await repo.saveSample(MetricsSnapshot(
        sessionId: sid,
        ts: DateTime.utc(2026, 10, 30, 8, 1),
        blinkRate: 12.5,
        perclos: 0.04,
        distanceCm: 55,
        fatigueScore: 31,
        validRatioPct: 96,
      ));
      final s = (await repo.samplesForSession(sid)).single;
      expect(s.blinkRate, 12.5);
      expect(s.perclos, 0.04);
      expect(s.distanceCm, 55);
      expect(s.fatigueScore, 31);
      expect(s.validRatioPct, 96);
      expect(MetricsRepository.sampleInterval, const Duration(seconds: 60));
    });

    test('purgeOld menghapus sampel lebih dari 30 hari', () async {
      final sid = await SessionRepository(db).start(SessionMode.ai);
      final repo = MetricsRepository(db);
      final now = DateTime.utc(2026, 10, 30, 12);
      for (final days in [31, 30, 29, 0]) {
        await repo.saveSample(MetricsSnapshot(
            sessionId: sid,
            ts: now.subtract(Duration(days: days, minutes: days == 30 ? 1 : 0)),
            validRatioPct: 100));
      }
      expect(await repo.purgeOld(now: now), 2);
      final left = await repo.samplesForSession(sid);
      expect(left.map((s) => s.ts),
          [isoUtc(now.subtract(const Duration(days: 29))), isoUtc(now)]);
    });

    test('dailySummary menghitung ringkasan hari dan menandai sinkronisasi', () async {
      final sessions = SessionRepository(db);
      final repo = MetricsRepository(db);
      final alerts = AlertRepository(db);
      final day = DateTime(2026, 10, 30);

      // Sesi AI 08:00–08:30 dan Timer 10:00–10:15, plus sesi kemarin (diabaikan).
      final ai = await sessions.start(SessionMode.ai, at: DateTime(2026, 10, 30, 8));
      await sessions.end(ai, at: DateTime(2026, 10, 30, 8, 30));
      final timer = await sessions.start(SessionMode.timer, at: DateTime(2026, 10, 30, 10));
      await sessions.end(timer, at: DateTime(2026, 10, 30, 10, 15));
      final old = await sessions.start(SessionMode.ai, at: DateTime(2026, 10, 29, 8));
      await sessions.end(old, at: DateTime(2026, 10, 29, 9));

      await repo.saveSample(MetricsSnapshot(
          sessionId: ai, ts: DateTime(2026, 10, 30, 8, 1), blinkRate: 10, distanceCm: 50,
          fatigueScore: 20, validRatioPct: 100));
      await repo.saveSample(MetricsSnapshot(
          sessionId: ai, ts: DateTime(2026, 10, 30, 8, 2), blinkRate: 14, distanceCm: 60,
          fatigueScore: 41, validRatioPct: 100));
      await repo.saveSample(MetricsSnapshot(
          sessionId: ai, ts: DateTime(2026, 10, 30, 8, 3), validRatioPct: 40)); // BR tak dilaporkan
      await repo.saveSample(MetricsSnapshot(
          sessionId: old, ts: DateTime(2026, 10, 29, 8, 1), blinkRate: 1, validRatioPct: 100));

      await alerts.record(sessionId: ai, type: AlertTypes.rest, action: AlertAction.followed,
          at: DateTime(2026, 10, 30, 8, 10));
      await alerts.record(sessionId: ai, type: AlertTypes.rule202020, action: AlertAction.dismissed,
          at: DateTime(2026, 10, 30, 8, 20));
      await alerts.record(sessionId: timer, type: AlertTypes.rule202020,
          action: AlertAction.followed, at: DateTime(2026, 10, 30, 10, 10));
      await alerts.record(sessionId: ai, type: AlertTypes.distance, action: AlertAction.followed,
          at: DateTime(2026, 10, 30, 8, 25));

      final s = await repo.dailySummary(day);
      expect(s.day, '2026-10-30');
      expect(s.screenMinutes, 45);
      expect(s.avgBlinkRate, 12);
      expect(s.avgDistanceCm, 55);
      expect(s.avgFatigueScore, 30.5);
      expect(s.alertsCount, 4);
      expect(s.breaksTaken, 2); // istirahat & 20-20-20 yang diikuti
      expect(s.synced, isFalse);

      await repo.markSynced('2026-10-30');
      expect(await repo.pendingSync(), isEmpty);
      // Dihitung ulang tanpa perubahan → tetap tersinkron.
      expect((await repo.dailySummary(day)).synced, isTrue);

      // Data baru → perlu dikirim ulang.
      await alerts.record(sessionId: ai, type: AlertTypes.blink, action: AlertAction.snoozed,
          at: DateTime(2026, 10, 30, 8, 29));
      final updated = await repo.dailySummary(day);
      expect(updated.alertsCount, 5);
      expect(updated.synced, isFalse);
      expect((await repo.pendingSync()).map((d) => d.day), ['2026-10-30']);
    });

    test('sesi yang masih berjalan dihitung sampai sekarang', () async {
      final sessions = SessionRepository(db);
      await sessions.start(SessionMode.ai, at: DateTime(2026, 10, 30, 23, 30));
      final s = await MetricsRepository(db)
          .dailySummary(DateTime(2026, 10, 30), now: DateTime(2026, 10, 31, 0, 30));
      expect(s.screenMinutes, 30); // dipotong di batas hari
      expect(s.avgBlinkRate, isNull);
    });
  });

  group('SettingsRepository', () {
    test('key-value: set, timpa, ambil, hapus', () async {
      final repo = SettingsRepository(db);
      expect(await repo.get('sensitivity'), isNull);
      await repo.set('sensitivity', 'sedang');
      await repo.set('interval_202020_min', '20');
      await repo.set('sensitivity', 'tinggi');
      expect(await repo.get('sensitivity'), 'tinggi');
      expect(await repo.all(), {'sensitivity': 'tinggi', 'interval_202020_min': '20'});
      await repo.remove('sensitivity');
      expect(await repo.get('sensitivity'), isNull);
    });
  });

  test('dayKey memakai tanggal lokal', () {
    expect(dayKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });
}
