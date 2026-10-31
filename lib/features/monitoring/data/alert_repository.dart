import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

/// Nilai kolom `alerts.type`, sesuai jenis pengingat DOCS_SPEC §9.5.
class AlertTypes {
  AlertTypes._();

  static const rest = 'break'; // Istirahat (S ≥ 60)
  static const distance = 'distance';
  static const blink = 'blink';
  static const rule202020 = '20-20-20';

  /// Jenis yang dihitung sebagai istirahat di `daily_summaries.breaks_taken`.
  static const breaks = [rest, rule202020];
}

final alertRepositoryProvider =
    Provider<AlertRepository>((ref) => AlertRepository(ref.watch(appDatabaseProvider)));

/// D5 Riwayat Pengingat (tabel `alerts`).
class AlertRepository {
  AlertRepository(this._db);

  final AppDatabase _db;

  Future<int> record({
    required int sessionId,
    required String type,
    required AlertAction action,
    DateTime? at,
  }) =>
      _db.into(_db.alerts).insert(AlertsCompanion.insert(
            sessionId: sessionId,
            ts: isoUtc(at ?? DateTime.now()),
            type: type,
            action: action,
          ));

  Future<List<Alert>> forSession(int sessionId) => (_db.select(_db.alerts)
        ..where((a) => a.sessionId.equals(sessionId))
        ..orderBy([(a) => OrderingTerm.asc(a.ts)]))
      .get();
}
