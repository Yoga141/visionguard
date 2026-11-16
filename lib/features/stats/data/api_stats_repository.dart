import '../../../core/constants/api_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import 'stats_repository.dart';

/// Statistik server: `POST /stats/daily` (upsert batch) dan
/// `GET /stats?range=7|30` (API_CONTRACT.md). Hanya angka ringkasan (§4.3).
class ApiStatsRepository implements StatsRepository {
  ApiStatsRepository(this._api, {required Future<int?> Function() deviceId}) : _deviceId = deviceId;

  final ApiClient _api;
  final Future<int?> Function() _deviceId;

  /// Rentang yang didukung server (UC-17).
  static const ranges = [7, 30];

  @override
  Future<void> uploadDaily(List<DailySummary> summaries) async {
    if (summaries.isEmpty) return;
    final deviceId = await _deviceId();
    if (deviceId == null) {
      // Sesi lama tanpa device_id: tunggu login berikutnya (data tetap lokal).
      throw const ApiException('Perangkat belum terdaftar. Masuk ulang untuk menyinkronkan statistik.');
    }
    for (var i = 0; i < summaries.length; i += ApiConstants.statsMaxBatch) {
      final batch = summaries.skip(i).take(ApiConstants.statsMaxBatch);
      await _api.post('/stats/daily', body: {
        'device_id': deviceId,
        'summaries': [for (final s in batch) toJson(s)],
      });
    }
  }

  @override
  Future<List<DailySummary>> range(String fromDay, String toDay) async {
    final span = DateTime.parse(toDay).difference(DateTime.parse(fromDay)).inDays + 1;
    final range = ranges.firstWhere((r) => r >= span, orElse: () => ranges.last);
    final res = await _api.get('/stats', query: {'range': range});
    final days = res['days'];
    if (days is! List) return const [];
    return [
      for (final d in days)
        if (d is Map<String, dynamic>) fromJson(d),
    ]
        .where((s) => s.day.compareTo(fromDay) >= 0 && s.day.compareTo(toDay) <= 0)
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  static Map<String, Object?> toJson(DailySummary s) => {
        'day': s.day,
        'screen_minutes': s.screenMinutes,
        'avg_blink_rate': s.avgBlinkRate,
        'avg_distance_cm': s.avgDistanceCm,
        'avg_fatigue_score': s.avgFatigueScore,
        'alerts_count': s.alertsCount,
        'breaks_taken': s.breaksTaken,
      };

  static DailySummary fromJson(Map<String, dynamic> m) {
    double? real(Object? v) => v is num ? v.toDouble() : null;
    int whole(Object? v) => v is num ? v.round() : 0;
    return DailySummary(
      day: m['day'] as String,
      screenMinutes: whole(m['screen_minutes']),
      avgBlinkRate: real(m['avg_blink_rate']),
      avgDistanceCm: real(m['avg_distance_cm']),
      avgFatigueScore: real(m['avg_fatigue_score']),
      alertsCount: whole(m['alerts_count']),
      breaksTaken: whole(m['breaks_taken']),
      synced: true,
    );
  }
}
