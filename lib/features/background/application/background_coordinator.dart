import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../monitoring/application/monitoring_controller.dart';
import '../../reminders/application/reminder_controller.dart';
import '../data/foreground_service.dart';
import '../data/screen_state.dart';
import 'app_visibility.dart';
import 'tray_menu.dart';

/// Menghubungkan pemantauan dengan perilaku latar belakang (PMT-06, KDL-02):
/// - Mode AI berjalan → foreground service + notifikasi permanen (Android);
///   berhenti/dijeda → service dihentikan.
/// - Layar mati (Android) → pemantauan dihentikan.
///
/// Dibaca sekali di `main.dart`; di desktop service-nya no-op.
final backgroundCoordinatorProvider = Provider<BackgroundCoordinator>((ref) {
  final c = BackgroundCoordinator(ref, trackLifecycle: ref.read(trackMobileLifecycleProvider));
  ref.onDispose(c.dispose);
  return c;
});

/// true di ponsel (bukan test): status latar diikuti lewat lifecycle aplikasi.
final trackMobileLifecycleProvider = Provider<bool>((ref) => false);

class BackgroundCoordinator {
  BackgroundCoordinator(this._ref, {bool trackLifecycle = false}) {
    _ref.listen<MonitoringState>(monitoringControllerProvider, (prev, next) => _onMonitoring(next),
        fireImmediately: true);
    _screenSub = _ref.read(screenEventsProvider).listen(_onScreen);
    if (trackLifecycle) {
      // Ponsel: aplikasi di latar → pengingat lewat notifikasi sistem.
      _lifecycle = AppLifecycleListener(
        onHide: () => _ref.read(appInBackgroundProvider.notifier).state = true,
        onShow: () => _ref.read(appInBackgroundProvider.notifier).state = false,
      );
    }
  }

  AppLifecycleListener? _lifecycle;

  final Ref _ref;
  StreamSubscription<ScreenEvent>? _screenSub;
  bool _serviceRunning = false;
  String? _lastText;

  static const title = 'VisionGuard memantau mata Anda';

  ForegroundServiceGateway get _service => _ref.read(foregroundServiceProvider);

  /// true selama foreground service seharusnya berjalan.
  bool get serviceRunning => _serviceRunning;

  void _onMonitoring(MonitoringState m) {
    final wantService = m.mode == MonitoringMode.ai && !m.paused;
    if (wantService) {
      final text = trayStatus(m, _ref.read(reminderControllerProvider));
      if (!_serviceRunning) {
        _serviceRunning = true;
        _lastText = text;
        unawaited(_service.start(title: title, text: text));
      } else if (text != _lastText) {
        _lastText = text;
        unawaited(_service.update(text: text));
      }
    } else if (_serviceRunning) {
      _serviceRunning = false;
      _lastText = null;
      unawaited(_service.stop());
    }
  }

  Future<void> _onScreen(ScreenEvent e) async {
    if (e == ScreenEvent.off) {
      await _ref.read(monitoringControllerProvider.notifier).stopForScreenOff();
    }
  }

  void dispose() {
    _lifecycle?.dispose();
    _screenSub?.cancel();
    if (_serviceRunning) unawaited(_service.stop());
  }
}
