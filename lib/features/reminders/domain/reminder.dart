import '../../../core/constants/cv_constants.dart';
import '../../monitoring/data/alert_repository.dart';

/// Jenis pengingat, **berurutan sesuai prioritas** (DOCS_SPEC §9.5, Tabel 2.6):
/// indeks lebih kecil = prioritas lebih tinggi.
enum ReminderType {
  rest(
    alertType: AlertTypes.rest,
    title: 'Istirahat',
    message: 'Mata tampak lelah. Istirahat 5 menit, yuk.',
    cooldown: CvConstants.restCooldown,
  ),
  distance(
    alertType: AlertTypes.distance,
    title: 'Jarak terlalu dekat',
    message: 'Posisi terlalu dekat, mundur sedikit.',
    cooldown: CvConstants.distanceCooldown,
  ),
  blink(
    alertType: AlertTypes.blink,
    title: 'Kedipkan mata',
    message: 'Kedipkan mata perlahan 10 kali.',
    cooldown: CvConstants.blinkCooldown,
  ),
  rule202020(
    alertType: AlertTypes.rule202020,
    title: '20-20-20',
    message: 'Lihat objek sejauh 6 meter selama 20 detik.',
    cooldown: null, // terjadwal oleh TimerService
  );

  const ReminderType({
    required this.alertType,
    required this.title,
    required this.message,
    required this.cooldown,
  });

  /// Nilai kolom `alerts.type`.
  final String alertType;
  final String title;

  /// Contoh pesan persis DOCS_SPEC §9.5.
  final String message;

  /// Cooldown minimum (PNG-07); null untuk pengingat terjadwal.
  final Duration? cooldown;

  /// 1 = tertinggi.
  int get priority => index + 1;
}

/// Metrik yang dievaluasi RuleEngine tiap 10 detik (Seq 4.22).
class ReminderMetrics {
  const ReminderMetrics({
    required this.t,
    this.fatigueScore,
    this.distanceCm,
    this.blinkRate,
    this.rule202020Due = false,
  });

  final DateTime t;

  /// Skor kelelahan 0–100 (null sebelum evaluasi pertama).
  final int? fatigueScore;

  /// Jarak wajah (cm); null bila tidak terukur.
  final double? distanceCm;

  /// Blink rate (kedipan/menit); null bila frame valid < 70%.
  final double? blinkRate;

  /// TimerService: waktu layar kontinu sudah mencapai interval 20-20-20.
  final bool rule202020Due;
}
