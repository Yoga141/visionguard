import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_source.dart';
import 'dummy_face_analyzer.dart';
import 'face_analyzer.dart';
import 'mediapipe_face_analyzer.dart';

/// Satu CameraSource untuk seluruh aplikasi (kamera hanya boleh dipakai satu
/// pihak dalam satu waktu).
final cameraSourceProvider = Provider<CameraSource>((ref) {
  final source = CameraSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Analyzer yang dipakai aplikasi. Bawaan [DummyFaceAnalyzer] (test & sebelum
/// pemilihan); `main.dart` meng-override dengan hasil [selectFaceAnalyzer].
final faceAnalyzerProvider = Provider<FaceAnalyzer>((ref) {
  final analyzer = DummyFaceAnalyzer();
  ref.onDispose(analyzer.dispose);
  return analyzer;
});

/// Batas waktu memuat model sebelum menyerah ke mode simulasi.
const modelLoadTimeout = Duration(seconds: 15);

/// Pemilihan analyzer otomatis (Tahap D): [MediaPipeFaceAnalyzer] bila
/// platform menyediakan image stream kamera (Android, iOS) dan model berhasil
/// dimuat; selain itu [DummyFaceAnalyzer] berlabel "mode simulasi" beserta
/// alasannya. Tidak pernah melempar error.
Future<FaceAnalyzer> selectFaceAnalyzer({
  TargetPlatform? platform,
  bool? underTest,
  FaceAnalyzer Function()? createMediaPipe,
}) async {
  final p = platform ?? defaultTargetPlatform;
  final testing = underTest ?? (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));
  if (testing) return DummyFaceAnalyzer();
  if (p != TargetPlatform.android && p != TargetPlatform.iOS) {
    return DummyFaceAnalyzer(
        reason: p == TargetPlatform.windows
            ? 'camera_windows belum menyediakan image stream'
            : 'platform ini belum didukung MediaPipe');
  }
  final mp = (createMediaPipe ?? MediaPipeFaceAnalyzer.new)();
  try {
    await mp.load().timeout(modelLoadTimeout);
    return mp;
  } catch (e) {
    debugPrint('MediaPipe gagal dimuat, memakai mode simulasi: $e');
    mp.dispose();
    return DummyFaceAnalyzer(reason: 'model MediaPipe gagal dimuat');
  }
}
