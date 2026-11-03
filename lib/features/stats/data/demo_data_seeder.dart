import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../monitoring/data/alert_repository.dart';

/// **Hanya mode debug.** Mengisi data contoh mentah (sessions, metric_samples
/// per menit, alerts) untuk [days] hari terakhir termasuk hari ini, agar
/// grafik tren bisa didemokan. Ringkasan harian lalu dihitung oleh alur
/// agregasi biasa (MetricsRepository.dailySummary), bukan ditulis langsung.
///
/// Data hanya angka (tidak ada gambar), sama seperti data pemantauan asli.
class DemoDataSeeder {
  DemoDataSeeder(this._db, {int seed = 42}) : _rnd = math.Random(seed);

  final AppDatabase _db;
  final math.Random _rnd;

  /// Mengembalikan jumlah sesi yang dibuat.
  Future<int> seed({required int days, DateTime? now}) async {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    var created = 0;
    await _db.transaction(() async {
      for (var i = days - 1; i >= 0; i--) {
        final day = DateTime(today.year, today.month, today.day - i);
        // Tren: makin lama makin lelah lalu membaik di akhir pekan.
        final fatigue = (0.3 + 0.5 * math.sin(i / days * math.pi)).clamp(0.0, 1.0);
        for (final (start, minutes) in _blocks(day, i == 0 ? current : null)) {
          await _session(start, minutes, fatigue);
          created++;
        }
      }
    });
    return created;
  }

  /// Blok kerja pagi & siang. Untuk hari ini, hanya blok yang sudah lewat
  /// (dipotong pada [cutoff]).
  List<(DateTime, int)> _blocks(DateTime day, DateTime? cutoff) {
    final blocks = <(DateTime, int)>[
      (day.add(Duration(hours: 8, minutes: _rnd.nextInt(40))), 90 + _rnd.nextInt(60)),
      (day.add(Duration(hours: 13, minutes: _rnd.nextInt(40))), 60 + _rnd.nextInt(90)),
    ];
    if (cutoff == null) return blocks;
    final result = <(DateTime, int)>[];
    for (final (start, minutes) in blocks) {
      final m = math.min(minutes, cutoff.difference(start).inMinutes);
      if (m > 0) result.add((start, m));
    }
    if (result.isEmpty) {
      // Masih dini hari: satu sesi singkat yang berakhir sekarang.
      final m = math.min(30, cutoff.difference(day).inMinutes);
      if (m > 0) result.add((cutoff.subtract(Duration(minutes: m)), m));
    }
    return result;
  }

  Future<void> _session(DateTime start, int minutes, double fatigue) async {
    final end = start.add(Duration(minutes: minutes));
    final id = await _db.into(_db.sessions).insert(SessionsCompanion.insert(
          mode: SessionMode.ai,
          startedAt: isoUtc(start),
          endedAt: Value(isoUtc(end)),
        ));
    await _db.batch((b) {
      for (var m = 1; m <= minutes; m++) {
        final progress = m / minutes; // makin lama sesi, makin lelah
        final f = (fatigue * 0.7 + progress * 0.3).clamp(0.0, 1.0);
        b.insert(
          _db.metricSamples,
          MetricSamplesCompanion.insert(
            sessionId: id,
            ts: isoUtc(start.add(Duration(minutes: m))),
            blinkRate: Value(_round1(17 - 9 * f + _noise(2))),
            perclos: Value(_round3((0.02 + 0.12 * f + _noise(0.01)).clamp(0, 1))),
            distanceCm: Value(_round1(60 - 15 * f + _noise(4))),
            fatigueScore: Value((20 + 55 * f + _noise(6)).round().clamp(0, 100)),
            validRatioPct: 85 + _rnd.nextInt(15),
          ),
        );
      }
      // Pengingat: 20-20-20 tiap ±20 menit, sebagian diikuti.
      for (var m = 20; m < minutes; m += 20) {
        b.insert(
          _db.alerts,
          AlertsCompanion.insert(
            sessionId: id,
            ts: isoUtc(start.add(Duration(minutes: m))),
            type: AlertTypes.rule202020,
            action: _action(followedChance: 0.75 - 0.4 * fatigue),
          ),
        );
      }
      if (fatigue > 0.5) {
        b.insert(
          _db.alerts,
          AlertsCompanion.insert(
            sessionId: id,
            ts: isoUtc(start.add(Duration(minutes: minutes ~/ 2, seconds: 30))),
            type: _rnd.nextBool() ? AlertTypes.blink : AlertTypes.rest,
            action: _action(followedChance: 0.6),
          ),
        );
      }
    });
  }

  AlertAction _action({required double followedChance}) {
    final r = _rnd.nextDouble();
    if (r < followedChance) return AlertAction.followed;
    return r < followedChance + (1 - followedChance) / 2 ? AlertAction.snoozed : AlertAction.dismissed;
  }

  double _noise(double amp) => (_rnd.nextDouble() * 2 - 1) * amp;
  double _round1(double v) => (v * 10).roundToDouble() / 10;
  double _round3(double v) => (v * 1000).roundToDouble() / 1000;
}
