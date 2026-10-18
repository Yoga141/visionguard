import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_source.dart';
import 'dummy_face_analyzer.dart';
import 'face_analyzer.dart';

/// Satu CameraSource untuk seluruh aplikasi (kamera hanya boleh dipakai satu
/// pihak dalam satu waktu).
final cameraSourceProvider = Provider<CameraSource>((ref) {
  final source = CameraSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Ganti baris ini dengan MediaPipeFaceAnalyzer() setelah model terpasang.
final faceAnalyzerProvider = Provider<FaceAnalyzer>((ref) {
  final analyzer = DummyFaceAnalyzer();
  ref.onDispose(analyzer.dispose);
  return analyzer;
});
