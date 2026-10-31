import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Mode sesi pemantauan (kolom `sessions.mode`).
enum SessionMode { ai, timer, check }

/// Respons pengguna terhadap pengingat (kolom `alerts.action`, DOCS_SPEC §9.5).
enum AlertAction { followed, snoozed, dismissed }

// Database lokal SQLite (DOCS_SPEC §12.3, SDD 3.3 b, Tabel 3.9).
//
// Semua waktu disimpan sebagai TEXT ISO-8601 UTC (lihat [isoUtc]) sehingga
// urutan string = urutan waktu. Tidak ada kolom untuk frame/gambar kamera:
// yang disimpan hanya angka hasil CV Engine (DOCS_SPEC §8.8, §15 no. 1).

/// D3 Kalibrasi — per kamera; dibuat ulang saat kamera diganti (KLB-04).
class Calibrations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cameraId => text()();
  RealColumn get earBaseline => real()();
  RealColumn get focalPx => real()();
  TextColumn get createdAt => text()();
}

/// Satu baris tiap pemantauan dimulai.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mode => textEnum<SessionMode>()();
  TextColumn get startedAt => text()();
  TextColumn get endedAt => text().nullable()();
}

/// D4 Metrik Sesi — per menit; dihapus otomatis setelah 30 hari.
class MetricSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get ts => text()();
  RealColumn get blinkRate => real().nullable()();
  RealColumn get perclos => real().nullable()();
  RealColumn get distanceCm => real().nullable()();
  IntColumn get fatigueScore => integer().nullable()();
  IntColumn get validRatioPct => integer()();
}

/// D5 Riwayat Pengingat.
class Alerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get ts => text()();
  TextColumn get type => text()();
  TextColumn get action => textEnum<AlertAction>()();
}

/// Ringkasan harian; `synced` menandai sudah terkirim ke server (D11).
class DailySummaries extends Table {
  TextColumn get day => text()(); // YYYY-MM-DD, waktu lokal
  IntColumn get screenMinutes => integer()();
  RealColumn get avgBlinkRate => real().nullable()();
  RealColumn get avgDistanceCm => real().nullable()();
  RealColumn get avgFatigueScore => real().nullable()();
  IntColumn get alertsCount => integer()();
  IntColumn get breaksTaken => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

/// D10 Pengaturan — key-value.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Format waktu yang dipakai di semua kolom TEXT waktu, mis.
/// `2026-10-30T01:02:03.456Z`. Dipotong ke milidetik agar panjangnya selalu
/// sama (perbandingan string tetap benar).
String isoUtc(DateTime t) =>
    DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true).toIso8601String();

@DriftDatabase(tables: [Calibrations, Sessions, MetricSamples, Alerts, DailySummaries, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(
        name: 'visionguard',
        native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
      );
}
