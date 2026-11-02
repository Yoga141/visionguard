import '../../../core/constants/cv_constants.dart';

/// Status Tunda & Mode Fokus (DOCS_SPEC §9.7, UC-15, PNG-06).
/// Selama tertahan, **semua** pengingat tidak ditampilkan; aktif lagi otomatis
/// setelah durasi berakhir. Mode Fokus dapat diakhiri lebih cepat.
class ReminderHold {
  DateTime? _snoozedUntil;
  DateTime? _focusUntil;

  DateTime? snoozedUntil(DateTime now) => _active(_snoozedUntil, now);
  DateTime? focusUntil(DateTime now) => _active(_focusUntil, now);

  bool isHeld(DateTime now) => snoozedUntil(now) != null || focusUntil(now) != null;

  /// Waktu berakhirnya penahanan yang paling akhir, atau null.
  DateTime? heldUntil(DateTime now) {
    final s = snoozedUntil(now), f = focusUntil(now);
    if (s == null) return f;
    if (f == null) return s;
    return s.isAfter(f) ? s : f;
  }

  /// Tunda 15/30/60 menit dari pengingat.
  DateTime snooze(int minutes, DateTime now) {
    if (!CvConstants.snoozeOptionsMin.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes', 'Pilihan tunda: ${CvConstants.snoozeOptionsMin}');
    }
    return _snoozedUntil = now.add(Duration(minutes: minutes));
  }

  DateTime startFocus(int minutes, DateTime now) {
    if (!CvConstants.focusOptionsMin.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes', 'Pilihan Mode Fokus: ${CvConstants.focusOptionsMin}');
    }
    return _focusUntil = now.add(Duration(minutes: minutes));
  }

  void endFocus() => _focusUntil = null;

  static DateTime? _active(DateTime? until, DateTime now) =>
      until != null && until.isAfter(now) ? until : null;
}
