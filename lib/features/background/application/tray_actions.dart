import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../monitoring/application/monitoring_controller.dart';
import '../../reminders/application/reminder_controller.dart';
import 'tray_menu.dart';

/// Menjalankan aksi menu tray (S-11) tanpa bergantung pada API tray native,
/// sehingga bisa diuji. Aksi jendela (buka, keluar) ditangani pemanggil.
class TrayActions {
  TrayActions(this._read);

  final T Function<T>(ProviderListenable<T>) _read;

  MonitoringController get _monitoring => _read(monitoringControllerProvider.notifier);

  /// Mengembalikan true bila aksi ditangani di sini.
  Future<bool> run(TrayAction action, {int? focusMinutes}) async {
    switch (action) {
      case TrayAction.pauseResume:
        final m = _read(monitoringControllerProvider);
        if (m.paused) {
          await _monitoring.resume();
        } else {
          await _monitoring.pause();
        }
        return true;
      case TrayAction.startFocus:
        if (focusMinutes != null) _read(reminderControllerProvider.notifier).startFocus(focusMinutes);
        return true;
      case TrayAction.endFocus:
        _read(reminderControllerProvider.notifier).endFocus();
        return true;
      case TrayAction.logout:
        await _monitoring.stop();
        await _read(authControllerProvider.notifier).logout();
        return true;
      case TrayAction.quit:
        await _monitoring.stop();
        return true;
      case TrayAction.openDashboard:
        return false;
    }
  }
}
