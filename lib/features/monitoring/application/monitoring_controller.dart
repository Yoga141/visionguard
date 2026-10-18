import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cv_engine/blink_analyzer.dart';
import '../../../cv_engine/camera_source.dart';
import '../../../cv_engine/cv_providers.dart';
import '../../../cv_engine/distance_estimator.dart';
import '../../../cv_engine/dummy_face_analyzer.dart';
import '../../../cv_engine/face_analyzer.dart';
import '../../../cv_engine/fatigue_scorer.dart';
import '../../calibration/application/calibration_controller.dart';

enum MonitoringMode { idle, ai, timer }

class MonitoringState {
  final MonitoringMode mode;
  final bool starting;
  /// true hanya jika kamera asli benar-benar menyala (badge "Kamera aktif").
  final bool cameraActive;
  /// true jika frame yang dianalisis berasal dari kamera asli (image stream).
  final bool usingRealCamera;
  final String analyzerName;

  // Metrik (SDD 2.5)
  final double? ear;
  final double? blinkRate;
  final double? perclos;
  final double? distanceCm;
  final double? fatigueScore;
  final int totalBlinks;
  final bool faceDetected;
  final DateTime? sessionStart;

  // Kredit (dummy sampai backend siap; SRS KRD-01)
  final int freeQuotaRemaining;
  final int creditBalance;
  final bool dayActive;

  // Mode Timer 20-20-20 (UC-12)
  final int secondsToNext202020;

  /// Hanya untuk DummyFaceAnalyzer (demo).
  final bool simulatingFatigue;

  final String? message;

  const MonitoringState({
    this.mode = MonitoringMode.idle,
    this.starting = false,
    this.cameraActive = false,
    this.usingRealCamera = false,
    this.analyzerName = '-',
    this.ear,
    this.blinkRate,
    this.perclos,
    this.distanceCm,
    this.fatigueScore,
    this.totalBlinks = 0,
    this.faceDetected = false,
    this.sessionStart,
    this.freeQuotaRemaining = 2,
    this.creditBalance = 0,
    this.dayActive = false,
    this.secondsToNext202020 = 20 * 60,
    this.simulatingFatigue = false,
    this.message,
  });

  FatigueLevel? get level => fatigueScore == null ? null : FatigueScorer.levelOf(fatigueScore!);

  double get screenMinutes => sessionStart == null
      ? 0
      : DateTime.now().difference(sessionStart!).inSeconds / 60.0;

  MonitoringState copyWith({
    MonitoringMode? mode,
    bool? starting,
    bool? cameraActive,
    bool? usingRealCamera,
    String? analyzerName,
    double? ear,
    double? blinkRate,
    double? perclos,
    double? distanceCm,
    double? fatigueScore,
    int? totalBlinks,
    bool? faceDetected,
    DateTime? sessionStart,
    int? freeQuotaRemaining,
    int? creditBalance,
    bool? dayActive,
    int? secondsToNext202020,
    bool? simulatingFatigue,
    String? message,
  }) =>
      MonitoringState(
        mode: mode ?? this.mode,
        starting: starting ?? this.starting,
        cameraActive: cameraActive ?? this.cameraActive,
        usingRealCamera: usingRealCamera ?? this.usingRealCamera,
        analyzerName: analyzerName ?? this.analyzerName,
        ear: ear ?? this.ear,
        blinkRate: blinkRate ?? this.blinkRate,
        perclos: perclos ?? this.perclos,
        distanceCm: distanceCm ?? this.distanceCm,
        fatigueScore: fatigueScore ?? this.fatigueScore,
        totalBlinks: totalBlinks ?? this.totalBlinks,
        faceDetected: faceDetected ?? this.faceDetected,
        sessionStart: sessionStart ?? this.sessionStart,
        freeQuotaRemaining: freeQuotaRemaining ?? this.freeQuotaRemaining,
        creditBalance: creditBalance ?? this.creditBalance,
        dayActive: dayActive ?? this.dayActive,
        secondsToNext202020: secondsToNext202020 ?? this.secondsToNext202020,
        simulatingFatigue: simulatingFatigue ?? this.simulatingFatigue,
        message: message ?? this.message,
      );

  /// Mengosongkan metrik saat pemantauan berhenti (status kredit dipertahankan).
  MonitoringState stopped({String? message}) => MonitoringState(
        freeQuotaRemaining: freeQuotaRemaining,
        creditBalance: creditBalance,
        dayActive: dayActive,
        message: message,
      );
}

final monitoringControllerProvider =
    NotifierProvider<MonitoringController, MonitoringState>(MonitoringController.new);

/// MonitoringSession (SDD 4.1): mengatur siklus mulai → analisis → berhenti.
///
/// Alur per frame: CameraSource → FaceAnalyzer → BlinkAnalyzer &
/// DistanceEstimator → FatigueScorer → state UI.
class MonitoringController extends Notifier<MonitoringState> {
  StreamSubscription<CameraFrame>? _sub;
  Timer? _timer;
  bool _busy = false;
  BlinkAnalyzer? _blink;
  DistanceEstimator? _distance;
  final _scorer = const FatigueScorer();

  CameraSource get _camera => ref.read(cameraSourceProvider);
  FaceAnalyzer get _analyzer => ref.read(faceAnalyzerProvider);

  @override
  MonitoringState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _timer?.cancel();
    });
    return const MonitoringState();
  }

  /// UC-09 Memulai Pemantauan AI.
  Future<void> startAi() async {
    if (state.mode == MonitoringMode.ai || state.starting) return;
    final calib = ref.read(calibrationControllerProvider);
    if (!calib.isComplete) {
      state = state.copyWith(message: 'Lakukan kalibrasi terlebih dahulu.');
      return;
    }

    // Aktivasi Hari Pemantauan (DFD 5.2): kuota gratis dulu, lalu kredit.
    if (!state.dayActive) {
      if (state.freeQuotaRemaining > 0) {
        state = state.copyWith(
          dayActive: true,
          freeQuotaRemaining: state.freeQuotaRemaining - 1,
          message: 'Hari Pemantauan AI aktif (kuota gratis).',
        );
      } else if (state.creditBalance > 0) {
        state = state.copyWith(
          dayActive: true,
          creditBalance: state.creditBalance - 1,
          message: 'Hari Pemantauan AI aktif (1 kredit terpakai).',
        );
      } else {
        state = state.copyWith(message: 'Kuota & kredit habis. Beralih ke Mode Timer.');
        useTimerMode();
        return;
      }
    }

    await _stopEverything();
    state = state.copyWith(starting: true);
    _blink = BlinkAnalyzer(baselineEar: calib.baselineEar!);
    _distance = DistanceEstimator(focalLengthPx: calib.focalLengthPx!);

    await _analyzer.load();
    await _camera.start();
    _sub = _camera.frames.listen(_onFrame);
    state = state.copyWith(
      mode: MonitoringMode.ai,
      starting: false,
      cameraActive: _camera.usingRealCamera,
      usingRealCamera: _camera.streamingRealFrames,
      analyzerName: _analyzer.name,
      sessionStart: DateTime.now(),
    );
  }

  /// UC-12 Mode Timer 20-20-20 tanpa kamera (gratis tanpa batas).
  void useTimerMode() {
    _stopEverything();
    state = state.stopped(message: state.message).copyWith(
          mode: MonitoringMode.timer,
          secondsToNext202020: 20 * 60,
          sessionStart: DateTime.now(),
        );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.secondsToNext202020 - 1;
      if (next <= 0) {
        state = state.copyWith(
          secondsToNext202020: 20 * 60,
          message: 'Waktunya 20-20-20! Lihat objek sejauh 6 meter selama 20 detik.',
        );
      } else {
        state = state.copyWith(secondsToNext202020: next);
      }
    });
  }

  /// UC-10 Menghentikan Pemantauan.
  Future<void> stop() async {
    await _stopEverything();
    state = state.stopped(message: 'Pemantauan dihentikan.');
  }

  bool get canSimulateFatigue => _analyzer is DummyFaceAnalyzer;

  /// Hanya untuk demo: membuat analyzer tiruan meniru mata lelah.
  void setFatigueSimulation(bool on) {
    final a = _analyzer;
    if (a is DummyFaceAnalyzer) {
      a.simulateFatigue = on;
      state = state.copyWith(simulatingFatigue: on);
    }
  }

  /// Hanya untuk demo: menambah kredit tanpa pembayaran.
  void addDemoCredit() => state = state.copyWith(creditBalance: state.creditBalance + 1);

  Future<void> _stopEverything() async {
    setFatigueSimulation(false);
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    await _camera.stop();
    _blink?.reset();
    _distance?.reset();
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await _analyzer.analyze(frame);
      final blink = _blink!.update(result);
      final distance = _distance!.update(result);

      double? score;
      if (blink.blinkRate != null && blink.perclos != null) {
        score = _scorer.score(
          blinkRate: blink.blinkRate!,
          perclos: blink.perclos!,
          screenMinutes: state.screenMinutes,
        );
      }

      state = state.copyWith(
        ear: blink.smoothedEar,
        blinkRate: blink.blinkRate,
        perclos: blink.perclos,
        distanceCm: distance,
        fatigueScore: score,
        totalBlinks: blink.totalBlinks,
        faceDetected: BlinkAnalyzer.isValidFrame(result),
      );
    } finally {
      _busy = false;
    }
  }
}
