import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import 'alert_repository.dart';

/// Ringkasan metrik satu menit yang disimpan ke `metric_samples`.
/// Hanya angka hasil CV Engine — tidak pernah frame/gambar kamera.
class MetricsSnapshot {
  final int sessionId;
  final DateTime ts;
  final double? blinkRate;
  final double? perclos;
  final double? distanceCm;
  final int? fatigueScore;
  final int validRatioPct;

  const MetricsSnapshot({
    required this.sessionId,
    required this.ts,
    this.blinkRate,
    this.perclos,
    this.distanceCm,
    this.fatigueScore,
    required this.validRatioPct,
  });
}

final metricsRepositoryProvider =
    Provider<MetricsRepository>((ref) => MetricsRepository(ref.watch(appDatabaseProvider)));

/// D4 Metrik Sesi (`metric_samples`) dan ringkasan harian (`daily_summaries`).
class MetricsRepository {
  MetricsRepository(this._db);

  final AppDatabase _db;

  /// Metrik disimpan setiap 60 detik (KDL-01: data hilang ≤ 1 menit saat crash).
  static const sampleInterval = Duration(seconds: 60);

  /// `metric_samples` dihapus otomatis setelah 30 hari (DOCS_SPEC §12.3).
  static const retention = Duration(days: 30);

  Future<int> saveSample(MetricsSnapshot m) => _db.into(_db.metricSamples).insert(
        MetricSamplesCompanion.insert(
          sessionId: m.sessionId,
          ts: isoUtc(m.ts),
          blinkRate: Value(m.blinkRate),
          perclos: Value(m.perclos),
          distanceCm: Value(m.distanceCm),
          fatigueScore: Value(m.fatigueScore),
          validRatioPct: m.validRatioPct,
        ),
      );

  Future<List<MetricSample>> samplesForSession(int sessionId) => (_db.select(_db.metricSamples)
        ..where((s) => s.sessionId.equals(sessionId))
        ..orderBy([(s) => OrderingTerm.asc(s.ts)]))
      .get();

  /// Menghapus sampel yang lebih tua dari [retention]. Mengembalikan jumlah baris terhapus.
  Future<int> purgeOld({DateTime? now}) {
    final cutoff = isoUtc((now ?? DateTime.now()).subtract(retention));
    return (_db.delete(_db.metricSamples)..where((s) => s.ts.isSmallerThanValue(cutoff))).go();
  }

  /// Menghitung ulang ringkasan hari [day] (waktu lokal) dari `sessions`,
  /// `metric_samples`, dan `alerts`, lalu menyimpannya ke `daily_summaries`.
  /// `synced` direset ke false hanya jika isinya berubah.
  Future<DailySummary> dailySummary(DateTime day, {DateTime? now}) async {
    final local = day.toLocal();
    final dayStart = DateTime(local.year, local.month, local.day);
    final dayEnd = DateTime(local.year, local.month, local.day + 1);
    final from = isoUtc(dayStart), to = isoUtc(dayEnd);
    final current = now ?? DateTime.now();

    // Menit menatap layar = durasi semua sesi (AI & Timer) yang jatuh di hari ini.
    final sessions = await (_db.select(_db.sessions)
          ..where((s) =>
              s.startedAt.isSmallerThanValue(to) &
              (s.endedAt.isNull() | s.endedAt.isBiggerThanValue(from))))
        .get();
    var screenSeconds = 0;
    for (final s in sessions) {
      final start = DateTime.parse(s.startedAt);
      final end = s.endedAt == null ? current : DateTime.parse(s.endedAt!);
      final a = start.isBefore(dayStart) ? dayStart : start;
      final b = end.isAfter(dayEnd) ? dayEnd : end;
      screenSeconds += math.max(0, b.difference(a).inSeconds);
    }

    final m = _db.metricSamples;
    final avgBr = m.blinkRate.avg(), avgDist = m.distanceCm.avg(), avgScore = m.fatigueScore.avg();
    final avgRow = await (_db.selectOnly(m)
          ..addColumns([avgBr, avgDist, avgScore])
          ..where(m.ts.isBiggerOrEqualValue(from) & m.ts.isSmallerThanValue(to)))
        .getSingle();

    final a = _db.alerts;
    final inDay = a.ts.isBiggerOrEqualValue(from) & a.ts.isSmallerThanValue(to);
    final alertsCount = await _countAlerts(inDay);
    final breaks = await _countAlerts(
        inDay & a.action.equalsValue(AlertAction.followed) & a.type.isIn(AlertTypes.breaks));

    final computed = DailySummary(
      day: dayKey(dayStart),
      screenMinutes: screenSeconds ~/ 60,
      avgBlinkRate: avgRow.read(avgBr),
      avgDistanceCm: avgRow.read(avgDist),
      avgFatigueScore: avgRow.read(avgScore),
      alertsCount: alertsCount,
      breaksTaken: breaks,
      synced: false,
    );

    final existing = await (_db.select(_db.dailySummaries)
          ..where((d) => d.day.equals(computed.day)))
        .getSingleOrNull();
    if (existing != null && existing.copyWith(synced: false) == computed) return existing;

    await _db.into(_db.dailySummaries).insertOnConflictUpdate(computed);
    return computed;
  }

  /// Ringkasan yang belum terkirim ke server (untuk SyncService nanti).
  Future<List<DailySummary>> pendingSync() =>
      (_db.select(_db.dailySummaries)..where((d) => d.synced.equals(false))).get();

  Future<void> markSynced(String day) =>
      (_db.update(_db.dailySummaries)..where((d) => d.day.equals(day)))
          .write(const DailySummariesCompanion(synced: Value(true)));

  Future<int> _countAlerts(Expression<bool> where) async {
    final c = _db.alerts.id.count();
    final row = await (_db.selectOnly(_db.alerts)
          ..addColumns([c])
          ..where(where))
        .getSingle();
    return row.read(c) ?? 0;
  }
}
