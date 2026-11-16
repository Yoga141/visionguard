import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/session_store.dart';
import 'api_stats_repository.dart';

/// Kontrak statistik server (StatsController, DOCS_SPEC §10.3 Seq 4.26).
/// Implementasi asli: `POST /stats/daily` (upsert `daily_stats`) dan
/// `GET /stats?range=7|30`. Hanya angka ringkasan yang dikirim (§4.3).
abstract class StatsRepository {
  /// STK-03: upsert ringkasan harian ke server.
  Future<void> uploadDaily(List<DailySummary> summaries);

  /// UC-17: ringkasan harian dalam rentang [fromDay, toDay] (kunci `YYYY-MM-DD`).
  Future<List<DailySummary>> range(String fromDay, String toDay);
}

/// Backend asli (bawaan) atau tiruan di memori (`USE_REMOTE_API=false` & test).
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  if (!ApiConstants.useRemoteApi) return FakeStatsRepository();
  final session = ref.watch(sessionStoreProvider);
  return ApiStatsRepository(ref.watch(apiClientProvider), deviceId: session.deviceId);
});

/// Meniru tabel server `daily_stats` (UNIQUE(user_id, device_id, day)).
class FakeStatsRepository implements StatsRepository {
  final Map<String, DailySummary> _rows = {};

  /// Bila true, setiap panggilan gagal (meniru offline; untuk test).
  bool offline = false;

  int uploadCalls = 0;

  @override
  Future<void> uploadDaily(List<DailySummary> summaries) async {
    if (offline) throw StateError('offline');
    uploadCalls++;
    for (final s in summaries) {
      _rows[s.day] = s.copyWith(synced: true);
    }
  }

  @override
  Future<List<DailySummary>> range(String fromDay, String toDay) async {
    if (offline) throw StateError('offline');
    final list = _rows.values
        .where((s) => s.day.compareTo(fromDay) >= 0 && s.day.compareTo(toDay) <= 0)
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return list;
  }
}
