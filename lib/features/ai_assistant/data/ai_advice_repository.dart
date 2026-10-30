import 'package:flutter/foundation.dart';

import '../../../core/constants/cv_constants.dart';
import '../../../cv_engine/fatigue_scorer.dart';

/// Ringkasan metrik yang boleh dikirim ke layanan Saran AI (DOCS_SPEC §17).
///
/// **Hanya angka ringkasan.** Tidak ada frame, gambar, landmark, atau EAR mentah.
class AdviceMetrics {
  const AdviceMetrics({
    required this.fatigueScore,
    this.blinkRate,
    this.perclos,
    this.distanceCm,
    this.screenMinutes,
  });

  /// Skor kelelahan 0–100 (int, DOCS_SPEC §16 #7).
  final int fatigueScore;

  /// Kedipan per menit.
  final double? blinkRate;

  /// Proporsi mata tertutup 0..1.
  final double? perclos;
  final double? distanceCm;

  /// Menit menatap layar tanpa istirahat.
  final int? screenMinutes;

  FatigueLevel get level => FatigueScorer.levelOf(fatigueScore.toDouble());

  /// Body JSON untuk POST /ai/advice (snake_case, §17).
  Map<String, Object?> toJson() => {
        'fatigue_score': fatigueScore,
        'blink_rate': blinkRate,
        'perclos': perclos,
        'distance_cm': distanceCm,
        'screen_minutes': screenMinutes,
      };
}

/// Kontrak fitur Saran AI. Implementasi:
/// - `DirectGeminiAdviceRepository` — panggil Gemini langsung dari klien
///   (**khusus pengembangan**).
/// - `ApiAiAdviceRepository` — lewat backend Laravel POST /ai/advice (**final**).
abstract class AiAdviceRepository {
  /// Selalu mengembalikan teks saran; jika layanan gagal, memakai
  /// [StaticAdvice] agar UX tetap berjalan.
  Future<String> getAdvice(AdviceMetrics metrics);
}

/// Saran statis berdasarkan level skor (§9.4) dan ambang pengingat (§9.5).
/// Dipakai saat AI dinonaktifkan, offline, atau layanan gagal.
class StaticAdvice {
  StaticAdvice._();

  static double get _minDistanceCm =>
      defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS
          ? CvConstants.minDistanceMobileCm
          : CvConstants.minDistanceDesktopCm;

  static String forMetrics(AdviceMetrics m) {
    final minCm = _minDistanceCm.round();
    return switch (m.level) {
      FatigueLevel.lelah => '⚠️ Tingkat kelelahan mata Anda tinggi!\n'
          '• Istirahatkan mata selama 10–15 menit.\n'
          '• Terapkan aturan 20-20-20: setiap 20 menit, lihat objek sejauh 6 meter selama 20 detik.\n'
          '• Pertimbangkan untuk berhenti bekerja di depan layar sementara waktu.',
      FatigueLevel.waspada => '🟡 Mata Anda mulai menunjukkan tanda-tanda kelelahan.\n'
          '• Kedipkan mata secara sadar beberapa kali.\n'
          '• Pastikan jarak mata ke layar minimal $minCm cm.\n'
          '• Lakukan peregangan mata: lihat ke kiri, kanan, atas, dan bawah.',
      FatigueLevel.normal => '✅ Kondisi mata Anda masih baik.\n'
          '• Tetap jaga jarak aman ke layar (minimal $minCm cm).\n'
          '• Ingat untuk berkedip secara teratur.\n'
          '• Atur kecerahan layar agar nyaman di mata.',
    };
  }
}
