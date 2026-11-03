import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/business_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../monitoring/application/monitoring_controller.dart';
import '../../monitoring/data/metrics_repository.dart';
import '../data/demo_data_seeder.dart';
import '../data/stats_repository.dart';

/// Satu titik grafik tren; [summary] null bila hari itu tidak ada data.
class TrendPoint {
  const TrendPoint(this.day, this.summary);
  final DateTime day;
  final DailySummary? summary;
}

@immutable
class StatsData {
  const StatsData({
    required this.today,
    required this.breakReminders,
    required this.trend,
    required this.synced,
  });

  /// Ringkasan hari ini; null = belum ada data hari ini (UC-16).
  final DailySummary? today;

  /// Pengingat istirahat + 20-20-20 hari ini (penyebut kepatuhan istirahat).
  final int breakReminders;

  /// [BusinessConstants.trendRangesDays] terpanjang, urut dari hari terlama.
  final List<TrendPoint> trend;

  /// false bila sinkronisasi/ambil data server gagal (offline → data lokal).
  final bool synced;

  /// Kepatuhan istirahat 0..1, null bila belum ada pengingat istirahat.
  double? get breakCompliance =>
      today == null || breakReminders == 0 ? null : (today!.breaksTaken / breakReminders).clamp(0, 1);

  /// [days] hari terakhir dari [trend].
  List<TrendPoint> lastDays(int days) =>
      trend.length <= days ? trend : trend.sublist(trend.length - days);

  /// Jumlah hari yang punya data dalam [points].
  static int daysWithData(List<TrendPoint> points) =>
      points.where((p) => p.summary != null && p.summary!.screenMinutes > 0).length;
}

/// Sumber tanggal "sekarang" untuk statistik (bisa diganti di test).
final statsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final statsControllerProvider =
    AsyncNotifierProvider<StatsController, StatsData>(StatsController.new);

/// Statistik & sinkronisasi (Seq 4.26, Activity 4.12, DFD 6.0):
/// 6.1 agregasi `metric_samples` + `alerts` → `daily_summaries` (synced=false),
/// 6.2 sinkronisasi ke server (StatsRepository), 6.3 ringkasan hari ini,
/// 6.4 tren 7/30 hari (server; offline → lokal).
class StatsController extends AsyncNotifier<StatsData> {
  MetricsRepository get _metrics => ref.read(metricsRepositoryProvider);
  StatsRepository get _server => ref.read(statsRepositoryProvider);
  DateTime get _now => ref.read(statsClockProvider)();

  static int get _maxRange => BusinessConstants.trendRangesDays.reduce((a, b) => a > b ? a : b);

  @override
  Future<StatsData> build() {
    // Pemantauan berhenti → ringkasan & tren dihitung ulang.
    ref.listen(monitoringControllerProvider.select((m) => m.mode), (prev, next) {
      if (prev != next && next == MonitoringMode.idle) refresh();
    });
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<StatsData>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  /// **Hanya debug**: isi data contoh lalu hitung ulang statistik.
  Future<void> seedDemoData() async {
    state = const AsyncLoading<StatsData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await DemoDataSeeder(ref.read(appDatabaseProvider))
          .seed(days: BusinessConstants.demoSeedDays, now: _now);
      return _load();
    });
  }

  Future<StatsData> _load() async {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(today.year, today.month, today.day - (_maxRange - 1));
    final todayKey = dayKey(today), fromKey = dayKey(from);

    // 6.1 Agregasi ulang hari yang punya sesi (hari tanpa aktivitas tidak
    // dibuatkan baris kosong).
    final active = await _metrics.activeDaysSince(from, now: now);
    DailySummary? todaySummary;
    for (final key in active) {
      final s = await _metrics.dailySummary(DateTime.parse(key), now: now);
      if (key == todayKey) todaySummary = s;
    }

    // 6.2 Sinkronisasi ringkasan yang belum terkirim (STK-03).
    var synced = true;
    try {
      final pending = await _metrics.pendingSync();
      if (pending.isNotEmpty) {
        await _server.uploadDaily(pending);
        for (final p in pending) {
          await _metrics.markSynced(p.day);
        }
      }
    } catch (e) {
      synced = false;
    }

    // 6.4 Tren dari server; offline → data lokal.
    List<DailySummary> rows;
    try {
      if (!synced) throw StateError('offline');
      rows = await _server.range(fromKey, todayKey);
    } catch (_) {
      synced = false;
      rows = await _metrics.summariesBetween(fromKey, todayKey);
    }
    final byDay = {for (final r in rows) r.day: r};
    final trend = [
      for (var i = 0; i < _maxRange; i++)
        () {
          final d = DateTime(from.year, from.month, from.day + i);
          return TrendPoint(d, byDay[dayKey(d)]);
        }(),
    ];

    final hasToday = todaySummary != null && todaySummary.screenMinutes > 0;
    return StatsData(
      today: hasToday ? todaySummary : null,
      breakReminders: hasToday ? await _metrics.breakRemindersCount(today) : 0,
      trend: trend,
      synced: synced,
    );
  }
}
