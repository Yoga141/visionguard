import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../calibration/application/calibration_controller.dart';
import '../../credits/application/credit_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../stats/application/stats_controller.dart';

final localDataCleanerProvider = Provider<LocalDataCleaner>(LocalDataCleaner.new);

/// Membersihkan data lokal saat logout (state di memori) dan hapus akun
/// (UC-05: kalibrasi, metrik, pengingat, ringkasan, pengaturan).
class LocalDataCleaner {
  LocalDataCleaner(this._ref);

  final Ref _ref;

  /// Logout: data akun sebelumnya (kredit, statistik server) tidak boleh
  /// terlihat oleh akun berikutnya.
  void resetInMemory() {
    _ref.invalidate(creditControllerProvider);
    _ref.invalidate(statsControllerProvider);
  }

  /// Hapus akun: semua tabel lokal dikosongkan lalu controller kembali ke bawaan.
  Future<void> wipeAll() async {
    try {
      await _ref.read(appDatabaseProvider).wipeAll();
    } catch (e) {
      debugPrint('LocalDataCleaner: gagal menghapus data lokal (${e.runtimeType}).');
    }
    await _ref.read(settingsControllerProvider.notifier).load();
    _ref.invalidate(calibrationControllerProvider);
    resetInMemory();
  }
}
