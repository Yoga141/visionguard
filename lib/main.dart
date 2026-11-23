import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'cv_engine/cv_providers.dart';
import 'features/background/application/background_coordinator.dart';
import 'features/background/data/autostart_service.dart';
import 'features/background/presentation/desktop_tray.dart';
import 'features/calibration/application/calibration_controller.dart';
import 'features/monitoring/data/metrics_repository.dart';
import 'features/monitoring/data/session_repository.dart';
import 'features/reminders/data/notification_service.dart';
import 'features/settings/application/settings_controller.dart';

/// Titik masuk aplikasi VisionGuard.
///
/// Urutan inisialisasi:
/// 1. [WidgetsFlutterBinding] — agar binding Flutter siap.
/// 2. Pemilihan analyzer wajah: MediaPipe bila didukung, selain itu mode
///    simulasi (Tahap D).
/// 3. Database lokal (DOCS_SPEC §12.3) — memuat pengaturan & kalibrasi
///    tersimpan, menutup sesi yang tertinggal terbuka, dan menghapus metrik
///    > 30 hari, lalu menyiapkan notifikasi sistem pengingat.
/// 4. Latar belakang: foreground service Android + layar mati (KDL-02) dan
///    system tray Windows (S-11); argumen `--autostart` → langsung ke tray.
/// 5. [runApp] — menjalankan aplikasi di dalam [UncontrolledProviderScope]
///    agar semua provider Riverpod dapat diakses dari mana saja. Layar pertama
///    (splash) mencoba auto-login dari token tersimpan (`GET /me`).
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final mobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (defaultTargetPlatform == TargetPlatform.android) FlutterForegroundTask.initCommunicationPort();

  final analyzer = await selectFaceAnalyzer();
  final container = ProviderContainer(overrides: [
    faceAnalyzerProvider.overrideWith((ref) {
      ref.onDispose(analyzer.dispose);
      return analyzer;
    }),
    trackMobileLifecycleProvider.overrideWithValue(mobile),
  ]);
  await prepareLocalData(container);

  // Latar belakang (Tahap E): foreground service Android & layar mati,
  // system tray Windows. Autostart (--autostart) langsung ke tray.
  container.read(backgroundCoordinatorProvider);
  if (DesktopTray.supported) {
    await DesktopTray(container).init(startHidden: args.contains(autostartArg));
  }

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
  // Notifikasi sistem pengingat (Windows & Android); gagal → pop-up saja.
  final notifier = container.read(systemNotifierProvider);
  if (notifier is LocalSystemNotifier) await notifier.init();
}
