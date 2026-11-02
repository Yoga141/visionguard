import '../../../core/constants/cv_constants.dart';
import '../domain/reminder.dart';

/// RuleEngine (SDD 4.1, DFD 4.1–4.2): memutuskan kapan pengingat muncul.
///
/// Aturan & prioritas persis DOCS_SPEC §9.5:
/// 1. Istirahat — skor ≥ 60, cooldown 20 menit.
/// 2. Jarak — jarak < ambang (50 cm desktop / 30 cm mobile) **terus-menerus**
///    selama 10 detik, cooldown 5 menit.
/// 3. Kedip — BR < 10/menit **terus-menerus** selama 3 menit, cooldown 10 menit.
/// 4. 20-20-20 — terjadwal (TimerService).
///
/// Kelas ini murni (tanpa timer & UI). Semua waktu berasal dari metrik,
/// sehingga mudah diuji. Status tunda/Mode Fokus diperiksa oleh ReminderService.
class RuleEngine {
  RuleEngine({required this.minDistanceCm});

  /// Ambang jarak sesuai platform (desktop / mobile).
  final double minDistanceCm;

  final Map<ReminderType, DateTime> _cooldowns = {};
  DateTime? _tooCloseSince;
  DateTime? _lowBlinkSince;

  /// Memperbarui pelacakan durasi kondisi dari metrik real-time (per frame).
  /// Opsional; [evaluate] juga memanggilnya. Dengan pemanggilan per frame,
  /// kondisi yang sempat terputus (mis. sejenak mundur) mereset hitungan.
  void observe(DateTime t, {double? distanceCm, double? blinkRate}) {
    _tooCloseSince = _track(_tooCloseSince, t, distanceCm != null && distanceCm < minDistanceCm);
    _lowBlinkSince =
        _track(_lowBlinkSince, t, blinkRate != null && blinkRate < CvConstants.lowBlinkRatePerMin);
  }

  /// Mengembalikan kandidat pengingat yang memenuhi kondisi dan tidak sedang
  /// cooldown, **berurutan menurut prioritas**. Yang ditampilkan hanya
  /// elemen pertama (satu pengingat sekaligus).
  List<ReminderType> evaluate(ReminderMetrics m) {
    observe(m.t, distanceCm: m.distanceCm, blinkRate: m.blinkRate);
    final score = m.fatigueScore;
    final candidates = <ReminderType>[
      if (score != null && score >= CvConstants.restReminderScore) ReminderType.rest,
      if (_heldFor(_tooCloseSince, m.t, CvConstants.tooCloseHold)) ReminderType.distance,
      if (_heldFor(_lowBlinkSince, m.t, CvConstants.lowBlinkHold)) ReminderType.blink,
      if (m.rule202020Due) ReminderType.rule202020,
    ];
    return [
      for (final r in candidates)
        if (!inCooldown(r, m.t)) r,
    ]..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Kandidat prioritas tertinggi, atau null.
  ReminderType? top(ReminderMetrics m) {
    final list = evaluate(m);
    return list.isEmpty ? null : list.first;
  }

  /// Dipanggil saat pengingat benar-benar ditampilkan → cooldown dimulai.
  void markShown(ReminderType type, DateTime at) => _cooldowns[type] = at;

  bool inCooldown(ReminderType type, DateTime now) {
    final cd = type.cooldown;
    final last = _cooldowns[type];
    if (cd == null || last == null) return false;
    return now.difference(last) < cd;
  }

  void reset() {
    _cooldowns.clear();
    _tooCloseSince = null;
    _lowBlinkSince = null;
  }

  static DateTime? _track(DateTime? since, DateTime t, bool active) =>
      active ? (since ?? t) : null;

  static bool _heldFor(DateTime? since, DateTime t, Duration hold) =>
      since != null && t.difference(since) >= hold;
}
