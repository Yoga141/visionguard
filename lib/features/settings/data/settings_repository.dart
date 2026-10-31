import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(appDatabaseProvider)));

/// D10 Pengaturan (tabel `settings`, key-value).
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async =>
      (await (_db.select(_db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> set(String key, String value) =>
      _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> remove(String key) => (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();

  Future<Map<String, String>> all() async =>
      {for (final s in await _db.select(_db.settings).get()) s.key: s.value};
}
