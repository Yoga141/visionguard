import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Satu koneksi SQLite untuk seluruh aplikasi. Di test, override dengan
/// `AppDatabase(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Kunci hari `YYYY-MM-DD` menurut waktu lokal (kolom `daily_summaries.day`).
String dayKey(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}';
}
