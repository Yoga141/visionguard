import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/calibration/application/calibration_controller.dart';
import 'features/monitoring/data/metrics_repository.dart';
import 'features/monitoring/data/session_repository.dart';
import 'features/settings/application/settings_controller.dart';

/// Titik masuk aplikasi VisionGuard.
///
/// Urutan inisialisasi:
/// 1. [WidgetsFlutterBinding] — agar binding Flutter siap.
/// 2. [dotenv.load] — memuat `.env` (GEMINI_API_KEY untuk fitur Saran AI,
///    khusus pengembangan; lihat DOCS_SPEC §17).
/// 3. Database lokal (DOCS_SPEC §12.3) — memuat pengaturan & kalibrasi
///    tersimpan, menutup sesi yang tertinggal terbuka, dan menghapus metrik
///    > 30 hari.
/// 4. [runApp] — menjalankan aplikasi di dalam [UncontrolledProviderScope]
///    agar semua provider Riverpod dapat diakses dari mana saja.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final container = ProviderContainer();
  await prepareLocalData(container);

  runApp(UncontrolledProviderScope(container: container, child: const VisionGuardApp()));
}

/// Kegagalan database lokal tidak boleh membuat aplikasi gagal dibuka.
Future<void> prepareLocalData(ProviderContainer container) async {
  try {
    await container.read(sessionRepositoryProvider).closeDangling();
    await container.read(metricsRepositoryProvider).purgeOld();
  } catch (e) {
    debugPrint('Gagal merawat database lokal: $e');
  }
  await container.read(settingsControllerProvider.notifier).load();
  await container.read(calibrationControllerProvider.notifier).restoreSaved();
}
