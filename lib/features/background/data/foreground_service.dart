import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Foreground service Android dengan notifikasi permanen selama Mode AI
/// (PMT-06, §4.4). Diabstraksikan agar koordinator bisa diuji.
abstract class ForegroundServiceGateway {
  Future<void> start({required String title, required String text});
  Future<void> update({required String text});
  Future<void> stop();
}

/// Platform tanpa foreground service (desktop, test).
class NoopForegroundService implements ForegroundServiceGateway {
  const NoopForegroundService();
  @override
  Future<void> start({required String title, required String text}) async {}
  @override
  Future<void> update({required String text}) async {}
  @override
  Future<void> stop() async {}
}

final foregroundServiceProvider = Provider<ForegroundServiceGateway>((ref) {
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !Platform.environment.containsKey('FLUTTER_TEST')) {
    return AndroidForegroundService();
  }
  return const NoopForegroundService();
});

/// Titik masuk isolate service. Kamera & analisis tetap di isolate utama;
/// service hanya menjaga proses & notifikasi permanen (DOCS_SPEC §16 #32).
@pragma('vm:entry-point')
void visionGuardServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}

/// Implementasi `flutter_foreground_task` (tipe layanan `camera`).
class AndroidForegroundService implements ForegroundServiceGateway {
  static const _serviceId = 4120;
  bool _initialized = false;

  void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'visionguard_monitoring',
        channelName: 'Pemantauan berjalan',
        channelDescription: 'Notifikasi permanen selama Pemantauan AI aktif',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: false,
        stopWithTask: true,
      ),
    );
    _initialized = true;
  }

  @override
  Future<void> start({required String title, required String text}) async {
    try {
      _init();
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
        return;
      }
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.camera],
        notificationTitle: title,
        notificationText: text,
        callback: visionGuardServiceCallback,
      );
    } catch (e) {
      // Gagal (mis. izin) tidak boleh menghentikan pemantauan di latar depan.
      debugPrint('Foreground service gagal dimulai: $e');
    }
  }

  @override
  Future<void> update({required String text}) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(notificationText: text);
      }
    } catch (e) {
      debugPrint('Foreground service gagal diperbarui: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('Foreground service gagal dihentikan: $e');
    }
  }
}
