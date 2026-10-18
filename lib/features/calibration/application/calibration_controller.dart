import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/cv_constants.dart';
import '../../../cv_engine/blink_analyzer.dart';
import '../../../cv_engine/camera_source.dart';
import '../../../cv_engine/cv_providers.dart';
import '../../../cv_engine/distance_estimator.dart';
import '../../../cv_engine/face_analyzer.dart';

enum CalibrationStep { idle, preparing, ready, eyeRecording, eyeDone, distanceRecording, done }

class CalibrationState {
  final CalibrationStep step;
  final double progress; // 0..1 untuk langkah yang sedang berjalan
  final double? baselineEar;
  final double? focalLengthPx;
  final bool focalIsEstimated; // true jika kalibrasi jarak dilewati
  final double? liveEar;
  final bool faceDetected;
  /// true hanya jika kamera asli benar-benar menyala (bukan mode simulasi).
  final bool usingRealCamera;
  final String? message;

  const CalibrationState({
    this.step = CalibrationStep.idle,
    this.progress = 0,
    this.baselineEar,
    this.focalLengthPx,
    this.focalIsEstimated = false,
    this.liveEar,
    this.faceDetected = false,
    this.usingRealCamera = false,
    this.message,
  });

  bool get isComplete => baselineEar != null && focalLengthPx != null;
  double? get tau => baselineEar == null ? null : CvConstants.tauFactor * baselineEar!;

  CalibrationState copyWith({
    CalibrationStep? step,
    double? progress,
    double? baselineEar,
    double? focalLengthPx,
    bool? focalIsEstimated,
    double? liveEar,
    bool? faceDetected,
    bool? usingRealCamera,
    String? message,
  }) =>
      CalibrationState(
        step: step ?? this.step,
        progress: progress ?? this.progress,
        baselineEar: baselineEar ?? this.baselineEar,
        focalLengthPx: focalLengthPx ?? this.focalLengthPx,
        focalIsEstimated: focalIsEstimated ?? this.focalIsEstimated,
        liveEar: liveEar ?? this.liveEar,
        faceDetected: faceDetected ?? this.faceDetected,
        usingRealCamera: usingRealCamera ?? this.usingRealCamera,
        message: message ?? this.message,
      );
}

final calibrationControllerProvider =
    NotifierProvider<CalibrationController, CalibrationState>(CalibrationController.new);

/// CalibrationService (SDD 4.1, DFD Level 2 Proses 2.0, UC-07 & UC-08).
///
/// Hasil kalibrasi saat ini disimpan di memori. Tahap berikutnya:
/// disimpan ke SQLite (tabel `calibrations`, D3) via drift.
class CalibrationController extends Notifier<CalibrationState> {
  StreamSubscription<CameraFrame>? _sub;
  bool _busy = false;
  final List<double> _earSamples = [];
  final List<double> _irisSamples = [];
  DateTime? _stepStart;
  int _lastFrameWidth = CvConstants.frameWidth;

  CameraSource get _camera => ref.read(cameraSourceProvider);
  FaceAnalyzer get _analyzer => ref.read(faceAnalyzerProvider);

  static double get referenceDistanceMm {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return isMobile ? CvConstants.refDistanceMobileMm : CvConstants.refDistanceDesktopMm;
  }

  @override
  CalibrationState build() {
    ref.onDispose(() => _sub?.cancel());
    return const CalibrationState();
  }

  Future<void> startCamera() async {
    if (_sub != null) return;
    state = state.copyWith(step: CalibrationStep.preparing, message: 'Menyiapkan kamera dan model...');
    await _analyzer.load();
    await _camera.start();
    _sub = _camera.frames.listen(_onFrame);
    state = state.copyWith(
      step: state.baselineEar == null ? CalibrationStep.ready : CalibrationStep.eyeDone,
      usingRealCamera: _camera.usingRealCamera,
      message: !_camera.usingRealCamera
          ? 'Kamera tidak tersedia — memakai frame simulasi.'
          : _camera.streamingRealFrames
              ? 'Kamera aktif. Posisikan wajah di tengah layar.'
              : 'Kamera aktif. Analisis wajah memakai frame simulasi '
                  '(image stream belum didukung di platform ini).',
    );
  }

  Future<void> stopCamera() async {
    await _sub?.cancel();
    _sub = null;
    await _camera.stop();
    state = state.copyWith(usingRealCamera: false);
  }

  void startEyeCalibration() {
    _earSamples.clear();
    _stepStart = DateTime.now();
    state = state.copyWith(
      step: CalibrationStep.eyeRecording,
      progress: 0,
      message: 'Tatap layar seperti biasa selama 10 detik...',
    );
  }

  void startDistanceCalibration() {
    _irisSamples.clear();
    _stepStart = DateTime.now();
    state = state.copyWith(
      step: CalibrationStep.distanceRecording,
      progress: 0,
      message: 'Tahan posisi pada jarak ${(referenceDistanceMm / 10).round()} cm...',
    );
  }

  /// UC-08 alur alternatif 2: f diperkirakan dari FOV kamera 60°.
  void skipDistanceCalibration() {
    state = state.copyWith(
      step: CalibrationStep.done,
      focalLengthPx: DistanceEstimator.fallbackFocal(_lastFrameWidth),
      focalIsEstimated: true,
      message: 'Kalibrasi jarak dilewati (akurasi lebih rendah).',
    );
  }

  void reset() {
    _earSamples.clear();
    _irisSamples.clear();
    state = CalibrationState(
      step: _sub == null ? CalibrationStep.idle : CalibrationStep.ready,
      usingRealCamera: _camera.usingRealCamera,
    );
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (_busy) return; // buang frame jika analisis sebelumnya belum selesai
    _busy = true;
    try {
      _lastFrameWidth = frame.width;
      final result = await _analyzer.analyze(frame);
      final valid = BlinkAnalyzer.isValidFrame(result);
      final ear = valid ? BlinkAnalyzer.averageEar(result.landmarks) : null;
      state = state.copyWith(liveEar: ear, faceDetected: valid);

      switch (state.step) {
        case CalibrationStep.eyeRecording:
          if (ear != null) _earSamples.add(ear);
          _tickEye();
        case CalibrationStep.distanceRecording:
          if (valid) _irisSamples.add(DistanceEstimator.irisWidthPx(result.landmarks));
          _tickDistance();
        default:
          break;
      }
    } finally {
      _busy = false;
    }
  }

  void _tickEye() {
    final elapsed = DateTime.now().difference(_stepStart!);
    final total = CvConstants.eyeCalibrationDuration;
    state = state.copyWith(progress: (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0));
    if (elapsed < total) return;

    if (_earSamples.length < 20) {
      // UC-07 alur alternatif: wajah tidak terdeteksi → ulangi
      state = state.copyWith(
        step: CalibrationStep.ready,
        progress: 0,
        message: 'Wajah kurang terdeteksi. Perbaiki pencahayaan lalu ulangi.',
      );
      return;
    }
    // Baseline EAR = median selama 10 detik (median tahan terhadap kedipan).
    final baseline = BlinkAnalyzer.median(_earSamples);
    state = state.copyWith(
      step: CalibrationStep.eyeDone,
      progress: 1,
      baselineEar: baseline,
      message: 'Kalibrasi mata selesai.',
    );
  }

  void _tickDistance() {
    final elapsed = DateTime.now().difference(_stepStart!);
    final total = CvConstants.distanceCalibrationDuration;
    state = state.copyWith(progress: (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0));
    if (elapsed < total) return;

    if (_irisSamples.length < 10) {
      state = state.copyWith(
        step: CalibrationStep.eyeDone,
        progress: 0,
        message: 'Posisi belum stabil. Ulangi pengukuran.',
      );
      return;
    }
    final irisPx = BlinkAnalyzer.median(_irisSamples);
    final f = DistanceEstimator.focalFromCalibration(irisPx, referenceDistanceMm);
    state = state.copyWith(
      step: CalibrationStep.done,
      progress: 1,
      focalLengthPx: f,
      focalIsEstimated: false,
      message: 'Kalibrasi berhasil!',
    );
  }
}
