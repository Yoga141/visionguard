import 'dart:math' as math;

import '../core/constants/cv_constants.dart';
import 'face_analyzer.dart';

/// Mengubah lebar iris (piksel) menjadi jarak wajah ke layar
/// (SDD 2.5.2, DFD Level 3 Proses 3.5).
///
///   d = f · D_iris / w_iris          (jarak, mm)
///   f = w_iris · d_ref / D_iris      (focal length saat kalibrasi, piksel)
class DistanceEstimator {
  DistanceEstimator({required this.focalLengthPx, this.smoothing = 0.3});

  double focalLengthPx;

  /// Faktor exponential moving average (0..1). Makin kecil makin halus.
  final double smoothing;
  double? _smoothedIrisPx;

  /// Lebar iris dalam piksel: rata-rata 469→471 (kanan) dan 474→476 (kiri).
  static double irisWidthPx(List<Point2> lm) {
    double d(int a, int b) {
      final dx = lm[a].x - lm[b].x, dy = lm[a].y - lm[b].y;
      return math.sqrt(dx * dx + dy * dy);
    }

    final right = d(CvConstants.rightIrisA, CvConstants.rightIrisB);
    final left = d(CvConstants.leftIrisA, CvConstants.leftIrisB);
    return (right + left) / 2;
  }

  /// d = f · D_iris / w_iris  → hasil dalam mm.
  static double distanceMm(double focalPx, double irisPx) {
    if (irisPx <= 0) return double.infinity;
    return focalPx * CvConstants.irisDiameterMm / irisPx;
  }

  /// f = w_iris · d_ref / D_iris  (kalibrasi pada jarak acuan).
  static double focalFromCalibration(double irisPx, double refDistanceMm) =>
      irisPx * refDistanceMm / CvConstants.irisDiameterMm;

  /// Perkiraan f bila kalibrasi jarak dilewati: sudut pandang kamera 60°.
  ///   f = (W / 2) / tan(FOV / 2)
  static double fallbackFocal(int frameWidth, {double fovDeg = CvConstants.fallbackFovDeg}) {
    final halfFovRad = (fovDeg / 2) * math.pi / 180;
    return (frameWidth / 2) / math.tan(halfFovRad);
  }

  /// Memproses satu frame; mengembalikan jarak dalam cm atau null jika tidak valid.
  double? update(FaceFrameResult frame) {
    if (!frame.faceDetected || frame.landmarks.length < CvConstants.landmarkCount) {
      return null;
    }
    final w = irisWidthPx(frame.landmarks);
    if (w <= 0) return null;
    _smoothedIrisPx = _smoothedIrisPx == null
        ? w
        : smoothing * w + (1 - smoothing) * _smoothedIrisPx!;
    return distanceMm(focalLengthPx, _smoothedIrisPx!) / 10; // mm → cm
  }

  void reset() => _smoothedIrisPx = null;
}
