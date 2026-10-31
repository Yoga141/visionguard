import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => SessionRepository(ref.watch(appDatabaseProvider)));

/// Tabel `sessions`: satu baris tiap pemantauan dimulai.
class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  /// Membuat baris sesi baru dan mengembalikan id-nya.
  Future<int> start(SessionMode mode, {DateTime? at}) => _db.into(_db.sessions).insert(
        SessionsCompanion.insert(mode: mode, startedAt: isoUtc(at ?? DateTime.now())),
      );

  Future<void> end(int id, {DateTime? at}) =>
      (_db.update(_db.sessions)..where((s) => s.id.equals(id) & s.endedAt.isNull()))
          .write(SessionsCompanion(endedAt: Value(isoUtc(at ?? DateTime.now()))));

  Future<Session?> byId(int id) =>
      (_db.select(_db.sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Menutup sesi yang tertinggal terbuka (aplikasi crash/ditutup paksa).
  /// `ended_at` diisi waktu sampel metrik terakhir, atau `started_at` bila
  /// belum ada sampel, sehingga durasi tidak dihitung berlebih (KDL-01).
  Future<int> closeDangling() async {
    final open = await (_db.select(_db.sessions)..where((s) => s.endedAt.isNull())).get();
    for (final s in open) {
      final lastTs = _db.metricSamples.ts.max();
      final row = await (_db.selectOnly(_db.metricSamples)
            ..addColumns([lastTs])
            ..where(_db.metricSamples.sessionId.equals(s.id)))
          .getSingle();
      await (_db.update(_db.sessions)..where((x) => x.id.equals(s.id)))
          .write(SessionsCompanion(endedAt: Value(row.read(lastTs) ?? s.startedAt)));
    }
    return open.length;
  }
}
