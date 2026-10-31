import '../core/constants/cv_constants.dart';
import 'blink_analyzer.dart';
import 'fatigue_scorer.dart';

/// Penjadwal evaluasi metrik selama Pemantauan AI (PMT-04, PMT-05).
///
/// - PERCLOS & skor kelelahan dievaluasi **setiap 10 detik**, bukan per frame
///   (DOCS_SPEC §16 #7). BR & jarak tetap real-time di luar kelas ini.
/// - Wajah tidak terdeteksi **> 10 detik** → perhitungan dijeda: tidak ada
///   evaluasi dan waktu menatap layar (T) tidak bertambah.
///
/// Semua waktu diambil dari timestamp frame, sehingga dapat diuji tanpa timer.
class SessionEvaluator {
  SessionEvaluator({this.scorer = const FatigueScorer()});

  final FatigueScorer scorer;

  DateTime? _lastFrame;
  DateTime? _lastFace;
  DateTime? _lastEval;
  Duration _active = Duration.zero;
  bool _paused = false;

  int? _score;
  double? _perclos;

  /// Skor terakhir hasil evaluasi 10 detik (null sebelum evaluasi pertama).
  int? get score => _score;

  /// PERCLOS terakhir hasil evaluasi 10 detik.
  double? get perclos => _perclos;

  /// true selama wajah tidak terdeteksi lebih dari [CvConstants.faceLostPause].
  bool get paused => _paused;

  /// Menit menatap layar (T), tanpa periode jeda.
  double get screenMinutes => _active.inMilliseconds / 60000.0;

  /// Memproses satu frame. Mengembalikan true jika evaluasi baru terjadi.
  bool update({required DateTime t, required bool faceDetected, required BlinkMetrics blink}) {
    _lastEval ??= t;
    _lastFace ??= t;
    if (faceDetected) _lastFace = t;

    final wasPaused = _paused;
    _paused = t.difference(_lastFace!) > CvConstants.faceLostPause;
    if (!_paused && !wasPaused && _lastFrame != null) _active += t.difference(_lastFrame!);
    _lastFrame = t;

    if (_paused) return false;
    if (wasPaused) {
      // Wajah kembali: mulai lagi jendela 10 detik dari sekarang.
      _lastEval = t;
      return false;
    }
    if (t.difference(_lastEval!) < CvConstants.scoreInterval) return false;

    _lastEval = t;
    _perclos = blink.perclos;
    if (blink.blinkRate != null && blink.perclos != null) {
      _score = scorer.score(
        blinkRate: blink.blinkRate!,
        perclos: blink.perclos!,
        screenMinutes: screenMinutes,
      );
    }
    return true;
  }

  void reset() {
    _lastFrame = null;
    _lastFace = null;
    _lastEval = null;
    _active = Duration.zero;
    _paused = false;
    _score = null;
    _perclos = null;
  }
}
