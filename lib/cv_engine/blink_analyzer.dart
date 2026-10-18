import 'dart:collection';
import 'dart:math' as math;

import '../core/constants/cv_constants.dart';
import 'face_analyzer.dart';

/// Hasil satu langkah [BlinkAnalyzer.update].
class BlinkMetrics {
  /// EAR mentah (rata-rata kiri & kanan) frame ini; null jika frame tidak valid.
  final double? ear;

  /// EAR setelah dihaluskan rata-rata 3 frame.
  final double? smoothedEar;

  /// Blink rate (kedipan/menit) dalam 60 detik terakhir.
  /// Null jika frame valid < 70% (SDD Tabel 2.4).
  final double? blinkRate;

  /// Proporsi frame valid dengan EAR < τ dalam 60 detik terakhir (0..1).
  final double? perclos;

  final bool eyesClosed;
  final int totalBlinks;

  const BlinkMetrics({
    this.ear,
    this.smoothedEar,
    this.blinkRate,
    this.perclos,
    this.eyesClosed = false,
    this.totalBlinks = 0,
  });
}

/// Menghitung EAR, blink rate, dan PERCLOS (SDD 2.5.1, DFD Level 3 Proses 3.4).
class BlinkAnalyzer {
  BlinkAnalyzer({required this.baselineEar, this.tauFactor = CvConstants.tauFactor});

  /// Median EAR hasil kalibrasi mata 10 detik.
  double baselineEar;

  /// Faktor ambang; diubah lewat pengaturan sensitivitas.
  double tauFactor;

  double get tau => tauFactor * baselineEar;

  final _smooth = Queue<double>();
  final _frames = Queue<_FrameSample>(); // jendela 60 detik
  final _blinks = Queue<DateTime>();
  DateTime? _closedSince;
  int _totalBlinks = 0;

  // ------------------------------------------------------------------
  // Rumus EAR (Soukupová & Čech, 2016)
  //   EAR = (‖p2 − p6‖ + ‖p3 − p5‖) / (2 · ‖p1 − p4‖)
  // ------------------------------------------------------------------
  static double eyeAspectRatio(List<Point2> p) {
    assert(p.length == 6);
    final vertical = _dist(p[1], p[5]) + _dist(p[2], p[4]);
    final horizontal = 2 * _dist(p[0], p[3]);
    if (horizontal == 0) return 0;
    return vertical / horizontal;
  }

  /// EAR rata-rata mata kiri dan kanan dari 478 landmark.
  static double averageEar(List<Point2> landmarks) {
    List<Point2> pick(List<int> idx) => [for (final i in idx) landmarks[i]];
    final r = eyeAspectRatio(pick(CvConstants.rightEye));
    final l = eyeAspectRatio(pick(CvConstants.leftEye));
    return (r + l) / 2;
  }

  static bool isValidFrame(FaceFrameResult f) =>
      f.faceDetected &&
      f.landmarks.length >= CvConstants.landmarkCount &&
      f.yawDeg.abs() <= CvConstants.maxHeadYawDeg;

  /// Memproses satu frame dan mengembalikan metrik terbaru.
  BlinkMetrics update(FaceFrameResult frame) {
    final now = frame.timestamp;
    _evictOld(now);

    if (!isValidFrame(frame)) {
      _frames.add(_FrameSample(now, valid: false, closed: false));
      _closedSince = null;
      return _metrics(now);
    }

    final ear = averageEar(frame.landmarks);
    _smooth.add(ear);
    while (_smooth.length > CvConstants.earSmoothingFrames) {
      _smooth.removeFirst();
    }
    final smoothed = _smooth.reduce((a, b) => a + b) / _smooth.length;
    final closed = smoothed < tau;

    // Deteksi kedipan: EAR < τ selama 100..400 ms
    if (closed) {
      _closedSince ??= now;
    } else if (_closedSince != null) {
      final ms = now.difference(_closedSince!).inMilliseconds;
      if (ms >= CvConstants.blinkMinMs && ms <= CvConstants.blinkMaxMs) {
        _blinks.add(now);
        _totalBlinks++;
      }
      // > 400 ms = mata tertutup panjang (tercermin di PERCLOS, bukan kedipan)
      _closedSince = null;
    }

    _frames.add(_FrameSample(now, valid: true, closed: closed));
    return _metrics(now, ear: ear, smoothed: smoothed, closed: closed);
  }

  BlinkMetrics _metrics(DateTime now, {double? ear, double? smoothed, bool closed = false}) {
    final total = _frames.length;
    final valid = _frames.where((f) => f.valid).length;
    final closedCount = _frames.where((f) => f.valid && f.closed).length;
    final validRatio = total == 0 ? 0.0 : valid / total;

    // Skala ke per menit bila jendela belum penuh 60 detik.
    double? br;
    if (validRatio >= CvConstants.minValidFrameRatio && _frames.isNotEmpty) {
      final spanS = math.max(
        1.0,
        now.difference(_frames.first.t).inMilliseconds / 1000.0,
      );
      final windowS = math.min(spanS, CvConstants.metricWindow.inSeconds.toDouble());
      br = _blinks.length * 60.0 / windowS;
    }

    return BlinkMetrics(
      ear: ear,
      smoothedEar: smoothed,
      blinkRate: br,
      perclos: valid == 0 ? null : closedCount / valid,
      eyesClosed: closed,
      totalBlinks: _totalBlinks,
    );
  }

  void _evictOld(DateTime now) {
    final cutoff = now.subtract(CvConstants.metricWindow);
    while (_frames.isNotEmpty && _frames.first.t.isBefore(cutoff)) {
      _frames.removeFirst();
    }
    while (_blinks.isNotEmpty && _blinks.first.isBefore(cutoff)) {
      _blinks.removeFirst();
    }
  }

  void reset() {
    _smooth.clear();
    _frames.clear();
    _blinks.clear();
    _closedSince = null;
    _totalBlinks = 0;
  }

  static double _dist(Point2 a, Point2 b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Median, dipakai saat kalibrasi untuk baseline EAR.
  static double median(List<double> values) {
    if (values.isEmpty) return 0;
    final s = [...values]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }
}

class _FrameSample {
  final DateTime t;
  final bool valid;
  final bool closed;
  _FrameSample(this.t, {required this.valid, required this.closed});
}
