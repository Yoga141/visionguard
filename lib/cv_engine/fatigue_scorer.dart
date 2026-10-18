import '../core/constants/cv_constants.dart';

enum FatigueLevel { normal, waspada, lelah }

extension FatigueLevelX on FatigueLevel {
  String get label => switch (this) {
        FatigueLevel.normal => 'Normal',
        FatigueLevel.waspada => 'Waspada',
        FatigueLevel.lelah => 'Lelah',
      };
}

/// Skor kelelahan 0..100 (SDD 2.5.3, Tabel 2.5).
///
///   s_BR = clamp((15 − BR) / 10, 0, 1)
///   s_P  = clamp(PERCLOS / 0,15, 0, 1)
///   s_T  = clamp(T / 60, 0, 1)
///   S    = 100 · (0,5·s_BR + 0,3·s_P + 0,2·s_T)
class FatigueScorer {
  const FatigueScorer();

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  double blinkComponent(double blinkRate) => _clamp01((15 - blinkRate) / 10);
  double perclosComponent(double perclos) => _clamp01(perclos / CvConstants.perclosMax);
  double timeComponent(double minutes) => _clamp01(minutes / CvConstants.screenMinutesMax);

  /// [blinkRate] per menit, [perclos] 0..1, [screenMinutes] menit tanpa istirahat.
  double score({
    required double blinkRate,
    required double perclos,
    required double screenMinutes,
  }) {
    final s = CvConstants.wBlink * blinkComponent(blinkRate) +
        CvConstants.wPerclos * perclosComponent(perclos) +
        CvConstants.wTime * timeComponent(screenMinutes);
    return 100 * s;
  }

  /// 0–39 Normal, 40–59 Waspada, 60–100 Lelah.
  static FatigueLevel levelOf(double score) {
    if (score >= 60) return FatigueLevel.lelah;
    if (score >= 40) return FatigueLevel.waspada;
    return FatigueLevel.normal;
  }
}
