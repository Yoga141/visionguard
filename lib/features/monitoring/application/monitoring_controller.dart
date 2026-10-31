import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/cv_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../cv_engine/blink_analyzer.dart';
import '../../../cv_engine/camera_source.dart';
import '../../../cv_engine/cv_providers.dart';
import '../../../cv_engine/distance_estimator.dart';
import '../../../cv_engine/dummy_face_analyzer.dart';
import '../../../cv_engine/face_analyzer.dart';
import '../../../cv_engine/fatigue_scorer.dart';
import '../../../cv_engine/session_evaluator.dart';
import '../../calibration/application/calibration_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../data/metrics_repository.dart';
import '../data/session_repository.dart';

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
  /// Skor 0–100, diperbarui tiap 10 detik (PMT-04).
  final int? fatigueScore;
  final int totalBlinks;
  final bool faceDetected;
  /// PMT-05: wajah tidak terdeteksi > 10 detik, perhitungan dijeda.
  final bool facePaused;
  /// Menit menatap layar tanpa periode jeda (T pada rumus skor).
  final double screenMinutes;
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
    this.facePaused = false,
    this.screenMinutes = 0,
    this.sessionStart,
    this.freeQuotaRemaining = 2,
    this.creditBalance = 0,
    this.dayActive = false,
    this.secondsToNext202020 = CvConstants.rule202020DefaultMin * 60,
    this.simulatingFatigue = false,
    this.message,
  });

  FatigueLevel? get level => fatigueScore == null ? null : FatigueScorer.levelOf(fatigueScore!);

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
    int? fatigueScore,
    int? totalBlinks,
    bool? faceDetected,
    bool? facePaused,
    double? screenMinutes,
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
        facePaused: facePaused ?? this.facePaused,
        screenMinutes: screenMinutes ?? this.screenMinutes,
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
///
/// Setiap pemantauan dicatat di tabel `sessions`; selama Mode AI, metrik
/// disimpan ke `metric_samples` setiap 60 detik (KDL-01). Hanya angka yang
/// disimpan, tidak pernah frame kamera.
class MonitoringController extends Notifier<MonitoringState> {
  StreamSubscription<CameraFrame>? _sub;
  Timer? _timer;
  Timer? _sampleTimer;
  bool _busy = false;
  BlinkAnalyzer? _blink;
  DistanceEstimator? _distance;
  SessionEvaluator? _evaluator;

  /// Id baris `sessions` yang sedang berjalan (null jika gagal disimpan).
  Future<int?>? _session;

  // Metrik terbaru apa adanya (null bila tidak dilaporkan) untuk sampel per menit.
  BlinkMetrics? _lastBlink;
  double? _lastDistance;
  int? _lastScore;
  int _framesTotal = 0;
  int _framesValid = 0;

  CameraSource get _camera => ref.read(cameraSourceProvider);
  FaceAnalyzer get _analyzer => ref.read(faceAnalyzerProvider);
  SessionRepository get _sessions => ref.read(sessionRepositoryProvider);
  MetricsRepository get _metrics => ref.read(metricsRepositoryProvider);
  AppSettings get _settings => ref.read(settingsControllerProvider);
  int get _intervalSeconds => _settings.interval202020Min * 60;

  @override
  MonitoringState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _timer?.cancel();
      _sampleTimer?.cancel();
    });
    // Pengaturan langsung diterapkan tanpa restart (UC-21).
    ref.listen(settingsControllerProvider.select((s) => s.sensitivity), (_, next) {
      _blink?.tauFactor = next.tauFactor;
    });
    ref.listen(settingsControllerProvider.select((s) => s.interval202020Min), (_, next) {
      if (state.mode == MonitoringMode.timer) {
        state = state.copyWith(secondsToNext202020: next * 60);
      }
    });
    return MonitoringState(secondsToNext202020: _intervalSeconds);
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
    _blink = BlinkAnalyzer(baselineEar: calib.baselineEar!, tauFactor: _settings.sensitivity.tauFactor);
    _distance = DistanceEstimator(focalLengthPx: calib.focalLengthPx!);
    _evaluator = SessionEvaluator();

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
    _beginSession(SessionMode.ai);
    _guard(_metrics.purgeOld);
    _sampleTimer = Timer.periodic(MetricsRepository.sampleInterval, (_) => saveSampleNow());
  }

  /// UC-12 Mode Timer 20-20-20 tanpa kamera (gratis tanpa batas).
  void useTimerMode() {
    _stopEverything();
    state = state.stopped(message: state.message).copyWith(
          mode: MonitoringMode.timer,
          secondsToNext202020: _intervalSeconds,
          sessionStart: DateTime.now(),
        );
    _beginSession(SessionMode.timer);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.secondsToNext202020 - 1;
      if (next <= 0) {
        state = state.copyWith(
          secondsToNext202020: _intervalSeconds,
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

  /// Faktor τ yang sedang dipakai BlinkAnalyzer (null bila Mode AI tidak berjalan).
  @visibleForTesting
  double? get activeTauFactor => _blink?.tauFactor;

  /// Menyimpan satu baris `metric_samples` dari metrik terbaru. Dipanggil
  /// tiap [MetricsRepository.sampleInterval] selama Mode AI.
  @visibleForTesting
  Future<void> saveSampleNow() async {
    final pending = _session;
    if (pending == null || state.mode != MonitoringMode.ai) return;
    final total = _framesTotal, valid = _framesValid;
    _framesTotal = 0;
    _framesValid = 0;
    final snapshot = (blink: _lastBlink, distance: _lastDistance, score: _lastScore);
    final id = await pending;
    if (id == null) return;
    await _guard(() => _metrics.saveSample(MetricsSnapshot(
          sessionId: id,
          ts: DateTime.now(),
          blinkRate: snapshot.blink?.blinkRate,
          perclos: snapshot.blink?.perclos,
          distanceCm: snapshot.distance,
          fatigueScore: snapshot.score,
          validRatioPct: total == 0 ? 0 : (valid * 100 / total).round(),
        )));
  }

  void _beginSession(SessionMode mode) {
    _framesTotal = 0;
    _framesValid = 0;
    _lastBlink = null;
    _lastDistance = null;
    _lastScore = null;
    _session = _guard(() => _sessions.start(mode));
  }

  /// Mengisi `ended_at` sesi yang berjalan. Bagian sinkronnya langsung
  /// melepas [_session], sehingga sesi baru yang dimulai sesudahnya aman.
  Future<void> _endSession() async {
    final pending = _session;
    _session = null;
    final id = await pending;
    if (id != null) await _guard(() => _sessions.end(id));
  }

  /// Kegagalan database lokal tidak boleh menghentikan pemantauan.
  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('Gagal menulis database lokal: $e');
      return null;
    }
  }

  Future<void> _stopEverything() async {
    final ending = _endSession();
    _sampleTimer?.cancel();
    _sampleTimer = null;
    setFatigueSimulation(false);
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    await _camera.stop();
    _blink?.reset();
    _distance?.reset();
    _evaluator?.reset();
    await ending;
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await _analyzer.analyze(frame);
      final blink = _blink!.update(result);
      final distance = _distance!.update(result);
      // PERCLOS & skor tiap 10 detik; dijeda bila wajah hilang > 10 detik.
      final evaluator = _evaluator!;
      evaluator.update(t: result.timestamp, faceDetected: result.faceDetected, blink: blink);

      final valid = BlinkAnalyzer.isValidFrame(result);
      _framesTotal++;
      if (valid) _framesValid++;
      _lastBlink = blink;
      _lastDistance = distance;
      _lastScore = evaluator.score;

      state = state.copyWith(
        ear: blink.smoothedEar,
        blinkRate: blink.blinkRate,
        perclos: evaluator.perclos,
        distanceCm: distance,
        fatigueScore: evaluator.score,
        totalBlinks: blink.totalBlinks,
        faceDetected: valid,
        facePaused: evaluator.paused,
        screenMinutes: evaluator.screenMinutes,
      );
    } finally {
      _busy = false;
    }
  }
}
