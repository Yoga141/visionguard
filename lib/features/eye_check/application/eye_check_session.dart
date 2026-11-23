import '../../../core/constants/cv_constants.dart';
import '../../../cv_engine/blink_analyzer.dart';
import '../../../cv_engine/distance_estimator.dart';
import '../../../cv_engine/face_analyzer.dart';
import '../../../cv_engine/fatigue_scorer.dart';

/// Hasil Sesi Cek Mata (UC-11, S-07).
class EyeCheckResult {
  const EyeCheckResult({
    required this.blinkRate,
    required this.perclos,
    required this.distanceCm,
    required this.score,
    required this.validRatio,
    required this.duration,
  });

  /// Kedipan per menit selama sesi.
  final double blinkRate;

  /// Proporsi frame valid dengan EAR < τ selama sesi (0..1).
  final double perclos;

  /// Rata-rata jarak wajah (cm); null bila iris tidak pernah terbaca.
  final double? distanceCm;
  final int score;

  /// Proporsi frame valid (wajah terdeteksi, |yaw| ≤ 30°).
  final double validRatio;
  final Duration duration;

  FatigueLevel get level => FatigueScorer.levelOf(score);
}

/// Mengakumulasi metrik sepanjang sesi 2 menit, memakai rumus §9.2–9.4 yang
/// sama dengan Pemantauan AI (BlinkAnalyzer, DistanceEstimator, FatigueScorer).
///
/// Berbeda dengan pemantauan, BR & PERCLOS di sini dihitung atas **seluruh**
/// durasi sesi (bukan jendela 60 detik bergulir), dan T pada skor = durasi
/// sesi (DOCS_SPEC §16 #33).
class EyeCheckSession {
  EyeCheckSession({required this.blink, required this.distance});

  final BlinkAnalyzer blink;
  final DistanceEstimator distance;

  int _frames = 0;
  int _valid = 0;
  int _closed = 0;
  double _distanceSum = 0;
  int _distanceCount = 0;
  int _blinks = 0;
  DateTime? _first;
  DateTime? _last;

  int get frames => _frames;

  void add(FaceFrameResult r) {
    _first ??= r.timestamp;
    _last = r.timestamp;
    _frames++;
    final m = blink.update(r);
    final d = distance.update(r);
    _blinks = m.totalBlinks;
    if (!BlinkAnalyzer.isValidFrame(r)) return;
    _valid++;
    if (m.eyesClosed) _closed++;
    if (d != null) {
      _distanceSum += d;
      _distanceCount++;
    }
  }

  double get validRatio => _frames == 0 ? 0 : _valid / _frames;

  /// Data cukup bila frame valid ≥ 70% (aturan pelaporan BR §9.2).
  bool get hasEnoughFace => _frames > 0 && validRatio >= CvConstants.minValidFrameRatio;

  /// null bila wajah kurang terdeteksi (alur "wajah tidak terdeteksi").
  EyeCheckResult? finish({Duration? duration}) {
    if (!hasEnoughFace) return null;
    final span = duration ??
        (_first == null ? Duration.zero : _last!.difference(_first!));
    final minutes = span.inMilliseconds / Duration.millisecondsPerMinute;
    if (minutes <= 0) return null;
    final br = _blinks / minutes;
    final perclos = _valid == 0 ? 0.0 : _closed / _valid;
    return EyeCheckResult(
      blinkRate: br,
      perclos: perclos,
      distanceCm: _distanceCount == 0 ? null : _distanceSum / _distanceCount,
      score: const FatigueScorer().score(blinkRate: br, perclos: perclos, screenMinutes: minutes),
      validRatio: validRatio,
      duration: span,
    );
  }
}
