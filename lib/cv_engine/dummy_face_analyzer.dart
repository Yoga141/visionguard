import 'dart:math' as math;

import '../core/constants/cv_constants.dart';
import 'camera_source.dart';
import 'face_analyzer.dart';

/// Implementasi [FaceAnalyzer] tiruan untuk tahap progress 30%.
///
/// Belum memakai MediaPipe. Kelas ini membangkitkan 478 landmark sintetis
/// yang meniru perilaku nyata: mata berkedip (~14x/menit, tutup ±180-300 ms) dan
/// jarak wajah yang bergerak perlahan antara ±40-65 cm. Dengan begitu rumus
/// EAR, PERCLOS, jarak, dan skor kelelahan dapat diuji end-to-end.
///
/// Akan diganti oleh MediaPipeFaceAnalyzer tanpa mengubah kelas lain.
class DummyFaceAnalyzer implements FaceAnalyzer {
  DummyFaceAnalyzer({this.simulatedFocalPx = 600, int seed = 42}) : _rng = math.Random(seed);

  /// Focal length "kamera virtual" yang dipakai untuk membangkitkan lebar iris.
  final double simulatedFocalPx;
  final math.Random _rng;

  /// Mode demo: kedipan jarang + mata sering tertutup lama, agar skor
  /// kelelahan naik ke Waspada/Lelah saat presentasi.
  bool simulateFatigue = false;

  DateTime? _start;
  DateTime? _nextBlink;
  DateTime? _blinkEnd;

  @override
  String get name => 'Dummy (simulasi, belum MediaPipe)';

  @override
  Future<void> load() async {
    // Simulasi waktu muat model.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _start = DateTime.now();
    _nextBlink = null;
    _blinkEnd = null;
  }

  @override
  Future<FaceFrameResult> analyze(CameraFrame frame) async {
    final t = frame.timestamp;
    _start ??= t;
    final elapsedS = t.difference(_start!).inMilliseconds / 1000.0;

    // --- Jadwal kedipan ---
    _nextBlink ??= t.add(const Duration(seconds: 2));
    if (_blinkEnd == null && !t.isBefore(_nextBlink!)) {
      // Normal: tutup 180-300 ms (tertangkap minimal 2 frame pada 10-15 fps),
      // jeda 2,5-6 detik. Lelah: jeda 6-10 detik, separuhnya mata tertutup
      // lama (>400 ms) yang masuk PERCLOS tetapi tidak dihitung sebagai kedipan.
      final closeMs = simulateFatigue
          ? (_rng.nextBool() ? 700 + _rng.nextInt(500) : 250)
          : 180 + _rng.nextInt(120);
      final gapMs = simulateFatigue ? 6000 + _rng.nextInt(4000) : 2500 + _rng.nextInt(3500);
      _blinkEnd = t.add(Duration(milliseconds: closeMs));
      _nextBlink = t.add(Duration(milliseconds: gapMs));
    }
    var openness = 1.0;
    if (_blinkEnd != null) {
      if (t.isBefore(_blinkEnd!)) {
        openness = 0.1;
      } else {
        _blinkEnd = null;
      }
    }

    // --- Jarak simulasi (mm) bergerak perlahan ---
    final distanceMm = 525 + 125 * math.sin(elapsedS / 8);
    final irisPx = simulatedFocalPx * CvConstants.irisDiameterMm / distanceMm;

    final lm = List<Point2>.filled(CvConstants.landmarkCount, Point2.zero);
    final cx = frame.width / 2;
    final cy = frame.height / 2;
    final eyeW = irisPx * 2.6; // lebar mata ≈ 2,6 × lebar iris
    final eyeH = eyeW * 0.30 * openness; // EAR terbuka ≈ 0,30

    _placeEye(lm, CvConstants.rightEye, cx - eyeW * 1.2, cy, eyeW, eyeH);
    _placeEye(lm, CvConstants.leftEye, cx + eyeW * 1.2, cy, eyeW, eyeH);
    _placeIris(lm, CvConstants.rightIrisA, CvConstants.rightIrisB, cx - eyeW * 1.2, cy, irisPx);
    _placeIris(lm, CvConstants.leftIrisA, CvConstants.leftIrisB, cx + eyeW * 1.2, cy, irisPx);

    return FaceFrameResult(
      faceDetected: true,
      landmarks: lm,
      yawDeg: 5 * math.sin(elapsedS / 5),
      timestamp: t,
    );
  }

  /// Menempatkan p1..p6 sesuai definisi EAR (SDD 2.5.1).
  void _placeEye(List<Point2> lm, List<int> idx, double cx, double cy, double w, double h) {
    final half = w / 2;
    lm[idx[0]] = Point2(cx - half, cy); // p1 sudut
    lm[idx[1]] = Point2(cx - w / 6, cy - h / 2); // p2 atas
    lm[idx[2]] = Point2(cx + w / 6, cy - h / 2); // p3 atas
    lm[idx[3]] = Point2(cx + half, cy); // p4 sudut
    lm[idx[4]] = Point2(cx + w / 6, cy + h / 2); // p5 bawah
    lm[idx[5]] = Point2(cx - w / 6, cy + h / 2); // p6 bawah
  }

  void _placeIris(List<Point2> lm, int a, int b, double cx, double cy, double w) {
    lm[a] = Point2(cx - w / 2, cy);
    lm[b] = Point2(cx + w / 2, cy);
  }

  @override
  void dispose() {}
}
