import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/cv_constants.dart';

/// Aksi yang dikirim balik dari notifikasi sistem.
class NotificationActions {
  NotificationActions._();

  static const ok = 'ok';
  static const snoozePrefix = 'snooze_';

  static String snooze(int minutes) => '$snoozePrefix$minutes';

  /// Menit tunda dari id aksi, atau null bila bukan aksi tunda.
  static int? snoozeMinutes(String actionId) => actionId.startsWith(snoozePrefix)
      ? int.tryParse(actionId.substring(snoozePrefix.length))
      : null;
}

/// Notifikasi sistem untuk pengingat (DOCS_SPEC §4.2, S-06). Hanya teks
/// pengingat yang ditampilkan; tidak ada data kamera.
abstract class SystemNotifier {
  /// Id aksi yang dipilih pengguna (lihat [NotificationActions]).
  Stream<String> get actions;

  /// Menampilkan notifikasi. Mengembalikan false bila tidak didukung, belum
  /// diinisialisasi, atau izin ditolak — pemanggil lalu memakai pop-up.
  Future<bool> show({required String title, required String body, required bool sound});

  Future<void> cancel();
}

final systemNotifierProvider = Provider<SystemNotifier>((ref) {
  final n = LocalSystemNotifier();
  ref.onDispose(n.dispose);
  return n;
});

/// Implementasi `flutter_local_notifications` (Windows & Android).
class LocalSystemNotifier implements SystemNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _actions = StreamController<String>.broadcast();
  bool _ready = false;

  static const _id = 2020;
  static const _channelId = 'visionguard_reminders';

  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  Stream<String> get actions => _actions.stream;

  /// Dipanggil sekali saat aplikasi dibuka. Kegagalan tidak fatal.
  Future<void> init() async {
    if (!platformSupported || _ready) return;
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          windows: WindowsInitializationSettings(
            appName: 'VisionGuard',
            appUserModelId: 'Itk.VisionGuard.Desktop.1',
            guid: '6d1f3a52-8f0e-4c4b-9a77-2f5b1c9e0d21',
          ),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      _ready = ok ?? false;
      if (_ready && defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notifikasi sistem tidak tersedia: $e');
      _ready = false;
    }
  }

  void _onResponse(NotificationResponse r) {
    final id = r.actionId;
    if (id != null && id.isNotEmpty) _actions.add(id);
  }

  @override
  Future<bool> show({required String title, required String body, required bool sound}) async {
    if (!_ready) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final enabled = await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
        if (enabled == false) return false;
      }
      // Android membatasi 3 tombol aksi: semuanya untuk Tunda; ketuk = buka app.
      final androidActions = [
        for (final m in CvConstants.snoozeOptionsMin.take(3))
          AndroidNotificationAction(NotificationActions.snooze(m), 'Tunda $m mnt',
              showsUserInterface: true),
      ];
      await _plugin.show(
        id: _id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Pengingat',
            channelDescription: 'Pengingat kesehatan mata VisionGuard',
            importance: Importance.high,
            priority: Priority.high,
            playSound: sound,
            timeoutAfter: CvConstants.reminderAutoDismiss.inMilliseconds,
            actions: androidActions,
          ),
          windows: WindowsNotificationDetails(
            audio: sound ? null : WindowsNotificationAudio.silent(),
            actions: [
              const WindowsAction(content: 'Oke', arguments: NotificationActions.ok),
              for (final m in CvConstants.snoozeOptionsMin)
                WindowsAction(content: 'Tunda $m mnt', arguments: NotificationActions.snooze(m)),
            ],
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi: $e');
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }

  void dispose() => _actions.close();
}
