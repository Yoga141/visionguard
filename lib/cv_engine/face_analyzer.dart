import 'camera_source.dart';

/// Titik 2D dalam koordinat piksel frame.
class Point2 {
  final double x;
  final double y;
  const Point2(this.x, this.y);

  static const zero = Point2(0, 0);
}

/// Hasil analisis satu frame oleh [FaceAnalyzer].
class FaceFrameResult {
  final bool faceDetected;

  /// 478 landmark wajah (termasuk iris) dalam piksel. Kosong jika tidak ada wajah.
  final List<Point2> landmarks;

  /// Sudut toleh kepala (derajat). Frame tidak valid jika |yaw| > 30.
  final double yawDeg;

  final DateTime timestamp;

  const FaceFrameResult({
    required this.faceDetected,
    required this.landmarks,
    required this.yawDeg,
    required this.timestamp,
  });

  factory FaceFrameResult.noFace(DateTime t) =>
      FaceFrameResult(faceDetected: false, landmarks: const [], yawDeg: 0, timestamp: t);
}

/// Antarmuka detektor wajah (SDD 4.1).
///
/// MonitoringSession bergantung pada antarmuka ini, bukan langsung pada
/// MediaPipe, sehingga model dapat diganti dan mudah diuji dengan data tiruan.
/// Implementasi saat ini: [DummyFaceAnalyzer]. Implementasi berikutnya:
/// MediaPipeFaceAnalyzer (TFLite via tflite_flutter).
abstract class FaceAnalyzer {
  /// Memuat model (mis. face_landmarker.tflite).
  Future<void> load();

  /// Menganalisis satu frame dan mengembalikan landmark.
  Future<FaceFrameResult> analyze(CameraFrame frame);

  void dispose();

  /// Label untuk ditampilkan di UI (jujur soal mode yang berjalan).
  String get name;
}
