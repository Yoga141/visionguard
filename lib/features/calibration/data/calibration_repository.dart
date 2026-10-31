import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

final calibrationRepositoryProvider =
    Provider<CalibrationRepository>((ref) => CalibrationRepository(ref.watch(appDatabaseProvider)));

/// D3 Kalibrasi (tabel `calibrations`). Satu kamera bisa punya beberapa
/// baris riwayat; yang dipakai selalu yang terbaru untuk `camera_id` itu (KLB-04).
class CalibrationRepository {
  CalibrationRepository(this._db);

  final AppDatabase _db;

  Future<Calibration> save({
    required String cameraId,
    required double earBaseline,
    required double focalPx,
    DateTime? at,
  }) =>
      _db.into(_db.calibrations).insertReturning(CalibrationsCompanion.insert(
            cameraId: cameraId,
            earBaseline: earBaseline,
            focalPx: focalPx,
            createdAt: isoUtc(at ?? DateTime.now()),
          ));

  /// Kalibrasi terbaru untuk [cameraId]; null jika kamera ini belum pernah dikalibrasi.
  Future<Calibration?> latestFor(String cameraId) => (_db.select(_db.calibrations)
        ..where((c) => c.cameraId.equals(cameraId))
        ..orderBy([(c) => OrderingTerm.desc(c.createdAt), (c) => OrderingTerm.desc(c.id)])
        ..limit(1))
      .getSingleOrNull();
}
