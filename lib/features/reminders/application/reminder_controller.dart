import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/cv_constants.dart';
import '../../../core/database/app_database.dart';
import '../../monitoring/data/alert_repository.dart';
import '../../settings/application/settings_controller.dart';
import '../data/notification_service.dart';
import '../domain/reminder.dart';
import 'break_verifier.dart';
import 'reminder_hold.dart';

/// Sumber waktu yang dapat diganti di test.
final reminderClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

enum ReminderPhase {
  /// Pesan + tombol Oke & Tunda.
  prompt,

  /// Hitung mundur istirahat 20-20-20 (UC-14).
  breakCountdown,

  /// Hasil istirahat ditampilkan sebentar sebelum pop-up ditutup.
  breakResult,
}

/// Pengingat yang sedang tampil.
@immutable
class ActiveReminder {
  const ActiveReminder({
    required this.type,
    required this.shownAt,
    required this.phase,
    this.breakSecondsLeft = 0,
    this.breakVerified,
    this.verifyBreak = false,
  });

  final ReminderType type;
  final DateTime shownAt;
  final ReminderPhase phase;
  final int breakSecondsLeft;

  /// null: tidak diverifikasi (Mode Timer) atau belum selesai.
  final bool? breakVerified;

  /// Mode AI: verifikasi istirahat lewat kamera (PNG-05).
  final bool verifyBreak;

  ActiveReminder copyWith({ReminderPhase? phase, int? breakSecondsLeft, bool? breakVerified}) =>
      ActiveReminder(
        type: type,
        shownAt: shownAt,
        phase: phase ?? this.phase,
        breakSecondsLeft: breakSecondsLeft ?? this.breakSecondsLeft,
        breakVerified: breakVerified ?? this.breakVerified,
        verifyBreak: verifyBreak,
      );
}

@immutable
class ReminderState {
  const ReminderState({this.active, this.popupVisible = false, this.snoozedUntil, this.focusUntil});

  final ActiveReminder? active;

  /// Pop-up dalam aplikasi ditampilkan (pengaturan pop-up, atau cadangan bila
  /// notifikasi sistem tidak tersedia).
  final bool popupVisible;
  final DateTime? snoozedUntil;
  final DateTime? focusUntil;

  bool get focusActive => focusUntil != null;
}

/// Dipanggil saat pengingat selesai dengan respons yang dicatat.
typedef ReminderDone = void Function(ReminderType type, AlertAction action);

final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderState>(ReminderController.new);

/// ReminderService (SDD 4.1): menampilkan pengingat, menunda, Mode Fokus,
/// dan mencatat respons ke tabel `alerts` (D5).
///
/// - Hanya satu pengingat sekaligus; selama ada yang tampil, [show] menolak.
/// - Pop-up tidak direspons dalam 15 detik → ditutup & dicatat `dismissed`.
/// - Notifikasi sistem dikirim bila diaktifkan di Pengaturan; bila tidak
///   didukung atau izin ditolak, pop-up tetap dipakai.
class ReminderController extends Notifier<ReminderState> {
  final _hold = ReminderHold();
  Timer? _autoDismiss;
  Timer? _breakTicker;
  Timer? _resultTimer;
  Timer? _holdExpiry;
  BreakVerifier? _verifier;
  Future<int?>? _session;
  ReminderDone? _onDone;
  StreamSubscription<String>? _actionSub;

  DateTime _now() => ref.read(reminderClockProvider)();
  SystemNotifier get _notifier => ref.read(systemNotifierProvider);
  AppSettings get _settings => ref.read(settingsControllerProvider);

  @override
  ReminderState build() {
    _actionSub = ref.read(systemNotifierProvider).actions.listen(_onNotificationAction);
    ref.onDispose(() {
      _actionSub?.cancel();
      _cancelTimers();
      _holdExpiry?.cancel();
    });
    return const ReminderState();
  }

  /// Pengingat tertahan oleh Tunda atau Mode Fokus.
  bool get isHeld => _hold.isHeld(_now());

  /// Boleh menampilkan pengingat baru sekarang.
  bool get canShow => state.active == null && !isHeld;

  /// Menampilkan pengingat. Mengembalikan false bila sedang ada pengingat,
  /// tertahan, atau semua jenis pengingat dimatikan di Pengaturan — pada
  /// kasus itu pemanggil tidak boleh memulai cooldown.
  bool show(
    ReminderType type, {
    Future<int?>? session,
    bool verifyBreak = false,
    ReminderDone? onDone,
  }) {
    if (!canShow) return false;
    final s = _settings;
    if (!s.popupEnabled && !s.notificationEnabled) return false;

    _session = session;
    _onDone = onDone;
    state = ReminderState(
      active: ActiveReminder(
        type: type,
        shownAt: _now(),
        phase: ReminderPhase.prompt,
        verifyBreak: verifyBreak,
      ),
      popupVisible: s.popupEnabled,
      snoozedUntil: state.snoozedUntil,
      focusUntil: state.focusUntil,
    );
    _autoDismiss = Timer(CvConstants.reminderAutoDismiss, autoDismissNow);
    unawaited(_deliver(type, s));
    return true;
  }

  Future<void> _deliver(ReminderType type, AppSettings s) async {
    var notified = false;
    if (s.notificationEnabled) {
      notified = await _notifier.show(title: type.title, body: type.message, sound: s.soundEnabled);
    }
    final current = state.active;
    if (current == null || current.type != type) return;
    if (!notified && !state.popupVisible) {
      // Notifikasi tidak didukung / izin ditolak → tetap pakai pop-up.
      state = _copy(popupVisible: true);
    }
    if (s.soundEnabled && !notified) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  /// Tombol **Oke**. Untuk 20-20-20, memulai hitung mundur istirahat 20 detik.
  void acknowledge() {
    final a = state.active;
    if (a == null || a.phase != ReminderPhase.prompt) return;
    _autoDismiss?.cancel();
    unawaited(_notifier.cancel());
    if (a.type != ReminderType.rule202020) {
      _finish(AlertAction.followed);
      return;
    }
    _verifier = a.verifyBreak ? BreakVerifier(start: _now()) : null;
    final total = CvConstants.breakCountdown.inSeconds;
    state = _copy(
        active: a.copyWith(phase: ReminderPhase.breakCountdown, breakSecondsLeft: total),
        popupVisible: true); // hitung mundur selalu terlihat (S-05)
    _breakTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final cur = state.active;
      if (cur == null) return;
      final left = cur.breakSecondsLeft - 1;
      if (left <= 0) {
        finishBreakNow();
      } else {
        state = _copy(active: cur.copyWith(breakSecondsLeft: left));
      }
    });
  }

  /// Laporan status wajah dari FaceAnalyzer selama hitung mundur (Mode AI).
  void observeFace({required DateTime t, required bool faceDetected, required double yawDeg}) {
    if (state.active?.phase != ReminderPhase.breakCountdown) return;
    _verifier?.observe(t: t, faceDetected: faceDetected, yawDeg: yawDeg);
  }

  /// Menyelesaikan hitung mundur istirahat (dipanggil timer; publik untuk test).
  @visibleForTesting
  void finishBreakNow() {
    final a = state.active;
    if (a == null || a.phase != ReminderPhase.breakCountdown) return;
    _breakTicker?.cancel();
    final v = _verifier;
    v?.finish(_now());
    // Mode Timer: verifikasi dilewati → dianggap mengikuti.
    final verified = v?.verified;
    _verifier = null;
    final action = verified == false ? AlertAction.dismissed : AlertAction.followed;
    _record(a.type, action);
    _onDone?.call(a.type, action);
    _onDone = null;
    state = _copy(
        active: a.copyWith(phase: ReminderPhase.breakResult, breakSecondsLeft: 0, breakVerified: verified));
    _resultTimer = Timer(CvConstants.breakResultVisible, closeResult);
  }

  /// Menutup tampilan hasil istirahat.
  void closeResult() {
    if (state.active?.phase != ReminderPhase.breakResult) return;
    _resultTimer?.cancel();
    state = _copy(clearActive: true, popupVisible: false);
  }

  /// Tombol **Tunda** 15/30/60 menit: semua pengingat ditahan.
  void snooze(int minutes) {
    _hold.snooze(minutes, _now());
    final a = state.active;
    if (a != null && a.phase == ReminderPhase.prompt) {
      _autoDismiss?.cancel();
      unawaited(_notifier.cancel());
      _finish(AlertAction.snoozed);
    }
    _scheduleHoldExpiry();
  }

  /// Pop-up tidak direspons 15 detik → `dismissed`.
  @visibleForTesting
  void autoDismissNow() {
    if (state.active?.phase != ReminderPhase.prompt) return;
    unawaited(_notifier.cancel());
    _finish(AlertAction.dismissed);
  }

  /// Mode Fokus dari Dashboard (UC-15).
  void startFocus(int minutes) {
    _hold.startFocus(minutes, _now());
    _scheduleHoldExpiry();
  }

  /// Mengakhiri Mode Fokus lebih cepat.
  void endFocus() {
    _hold.endFocus();
    _scheduleHoldExpiry();
  }

  /// Pemantauan berhenti: tutup pengingat yang tampil tanpa mencatat.
  void closeActive() {
    _cancelTimers();
    _verifier = null;
    _onDone = null;
    _session = null;
    if (state.active != null) unawaited(_notifier.cancel());
    state = _copy(clearActive: true, popupVisible: false);
  }

  /// Memperbarui status tunda/fokus yang sudah kedaluwarsa (mis. untuk UI).
  void refreshHold() {
    final now = _now();
    state = ReminderState(
      active: state.active,
      popupVisible: state.popupVisible,
      snoozedUntil: _hold.snoozedUntil(now),
      focusUntil: _hold.focusUntil(now),
    );
  }

  void _onNotificationAction(String actionId) {
    if (actionId == NotificationActions.ok) {
      acknowledge();
      return;
    }
    final m = NotificationActions.snoozeMinutes(actionId);
    if (m != null && CvConstants.snoozeOptionsMin.contains(m)) snooze(m);
  }

  void _finish(AlertAction action) {
    final a = state.active;
    if (a == null) return;
    _cancelTimers();
    _record(a.type, action);
    _onDone?.call(a.type, action);
    _onDone = null;
    state = _copy(clearActive: true, popupVisible: false);
  }

  void _record(ReminderType type, AlertAction action) {
    final pending = _session;
    if (pending == null) return;
    final repo = ref.read(alertRepositoryProvider);
    final at = _now();
    unawaited(() async {
      try {
        final id = await pending;
        if (id != null) {
          await repo.record(sessionId: id, type: type.alertType, action: action, at: at);
        }
      } catch (e) {
        debugPrint('Gagal mencatat pengingat: $e');
      }
    }());
  }

  /// Menyegarkan status tunda/fokus dan menjadwalkan penyegaran berikutnya
  /// tepat saat penahanan terdekat berakhir.
  void _scheduleHoldExpiry() {
    _holdExpiry?.cancel();
    refreshHold();
    final now = _now();
    DateTime? next;
    for (final t in [_hold.snoozedUntil(now), _hold.focusUntil(now)]) {
      if (t != null && (next == null || t.isBefore(next))) next = t;
    }
    if (next != null) _holdExpiry = Timer(next.difference(now), _scheduleHoldExpiry);
  }

  void _cancelTimers() {
    _autoDismiss?.cancel();
    _breakTicker?.cancel();
    _resultTimer?.cancel();
  }

  ReminderState _copy({ActiveReminder? active, bool clearActive = false, bool? popupVisible}) =>
      ReminderState(
        active: clearActive ? null : (active ?? state.active),
        popupVisible: popupVisible ?? state.popupVisible,
        snoozedUntil: state.snoozedUntil,
        focusUntil: state.focusUntil,
      );
}
