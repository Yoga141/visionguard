import '../../../core/constants/cv_constants.dart';
import '../../monitoring/application/monitoring_controller.dart';
import '../../reminders/application/reminder_controller.dart';

/// Aksi menu system tray (S-11).
enum TrayAction { pauseResume, startFocus, endFocus, openDashboard, logout, quit }

/// Satu baris menu tray. [action] null = label saja (mis. status).
class TrayEntry {
  const TrayEntry({
    required this.label,
    this.action,
    this.focusMinutes,
    this.enabled = true,
    this.children = const [],
  }) : separator = false;

  const TrayEntry.separator()
      : label = '',
        action = null,
        focusMinutes = null,
        enabled = false,
        children = const [],
        separator = true;

  final String label;
  final TrayAction? action;
  final int? focusMinutes;
  final bool enabled;
  final List<TrayEntry> children;
  final bool separator;
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

/// Teks status untuk menu & tooltip tray.
String trayStatus(MonitoringState m, ReminderState r) {
  final base = switch (m.mode) {
    MonitoringMode.idle => 'Pemantauan tidak berjalan',
    MonitoringMode.ai when m.paused => 'Pemantauan AI dijeda',
    MonitoringMode.ai when m.facePaused => 'Pemantauan AI • wajah tidak terdeteksi',
    MonitoringMode.ai => 'Pemantauan AI berjalan'
        '${m.fatigueScore == null ? '' : ' • skor ${m.fatigueScore}'}',
    MonitoringMode.timer when m.paused => 'Mode Timer dijeda',
    MonitoringMode.timer when m.waitingForCamera => 'Mode Timer • menunggu kamera',
    MonitoringMode.timer => 'Mode Timer 20-20-20 berjalan',
  };
  final focus = r.focusUntil;
  return focus == null ? base : '$base • Fokus hingga ${_hhmm(focus)}';
}

/// Isi menu tray: status, Jeda/Lanjut, Mode Fokus, Buka Dashboard, Logout,
/// Keluar (DOCS_SPEC §7.3 S-11).
List<TrayEntry> buildTrayMenu({
  required MonitoringState monitoring,
  required ReminderState reminders,
  required bool loggedIn,
}) {
  final running = monitoring.mode != MonitoringMode.idle;
  return [
    TrayEntry(label: trayStatus(monitoring, reminders), enabled: false),
    const TrayEntry.separator(),
    TrayEntry(
      label: monitoring.paused ? 'Lanjutkan pemantauan' : 'Jeda pemantauan',
      action: TrayAction.pauseResume,
      enabled: running,
    ),
    TrayEntry(
      label: 'Mode Fokus',
      enabled: running,
      children: [
        for (final minutes in CvConstants.focusOptionsMin)
          TrayEntry(label: '$minutes menit', action: TrayAction.startFocus, focusMinutes: minutes),
        if (reminders.focusActive) ...[
          const TrayEntry.separator(),
          const TrayEntry(label: 'Akhiri Mode Fokus', action: TrayAction.endFocus),
        ],
      ],
    ),
    const TrayEntry.separator(),
    const TrayEntry(label: 'Buka Dashboard', action: TrayAction.openDashboard),
    TrayEntry(label: 'Logout', action: TrayAction.logout, enabled: loggedIn),
    const TrayEntry(label: 'Keluar', action: TrayAction.quit),
  ];
}
