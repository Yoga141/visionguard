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
import '../../../core/network/api_exception.dart';
import '../../credits/application/credit_controller.dart';
import '../../credits/domain/credit_models.dart';
import '../../reminders/application/reminder_controller.dart';
import '../../reminders/application/rule_engine.dart';
import '../../reminders/application/timer_service.dart';
import '../../reminders/domain/reminder.dart';
import '../../settings/application/settings_controller.dart';
import '../data/metrics_repository.dart';
import '../data/session_repository.dart';

enum MonitoringMode { idle, ai, timer }

/// Hasil [MonitoringController.startAi].
enum StartAiOutcome {
  started,
  alreadyRunning,
  notCalibrated,
  /// 402: kuota gratis & kredit habis → UI menawarkan beli kredit / Mode Timer.
  insufficientCredit,
  /// Server tak terjangkau & hari belum aktif → sudah beralih ke Mode Timer.
  offlineTimerMode,
  /// Kamera dipakai aplikasi lain / izin ditolak → Mode Timer + coba lagi
  /// tiap 60 detik (UC-09 alur alternatif, PMT-08).
  cameraUnavailable,
}

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

  /// Sisa detik menuju pengingat 20-20-20 (TimerService; Mode AI & Timer).
  final int secondsToNext202020;

  /// Hanya untuk DummyFaceAnalyzer (demo).
  final bool simulatingFatigue;
  final bool simulatingTooClose;

  /// Opsi debug: interval 20-20-20 dipercepat menjadi
  /// [CvConstants.debugRule202020Min] menit.
  final bool fast202020;

  /// Dijeda pengguna (tray / Dashboard): kamera & timer berhenti, mode tetap.
  final bool paused;

  /// Mode Timer karena kamera tidak bisa dibuka; dicoba lagi tiap 60 detik.
  final bool waitingForCamera;

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
    this.secondsToNext202020 = CvConstants.rule202020DefaultMin * 60,
    this.simulatingFatigue = false,
    this.simulatingTooClose = false,
    this.fast202020 = false,
    this.paused = false,
    this.waitingForCamera = false,
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
    int? secondsToNext202020,
    bool? simulatingFatigue,
    bool? simulatingTooClose,
    bool? fast202020,
    bool? paused,
    bool? waitingForCamera,
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
        secondsToNext202020: secondsToNext202020 ?? this.secondsToNext202020,
        simulatingFatigue: simulatingFatigue ?? this.simulatingFatigue,
        simulatingTooClose: simulatingTooClose ?? this.simulatingTooClose,
        fast202020: fast202020 ?? this.fast202020,
        paused: paused ?? this.paused,
        waitingForCamera: waitingForCamera ?? this.waitingForCamera,
        message: message ?? this.message,
      );

  /// Mengosongkan metrik saat pemantauan berhenti.
  MonitoringState stopped({String? message}) => MonitoringState(
        secondsToNext202020: secondsToNext202020,
        fast202020: fast202020,
        message: message,
      );
}

final monitoringControllerProvider =
    NotifierProvider<MonitoringController, MonitoringState>(MonitoringController.new);

/// MonitoringSession (SDD 4.1): mengatur siklus mulai → analisis → berhenti.
///
/// Alur per frame: CameraSource → FaceAnalyzer → BlinkAnalyzer &
/// DistanceEstimator → FatigueScorer → state UI. Tiap 10 detik (saat
/// SessionEvaluator mengevaluasi) metrik diteruskan ke RuleEngine; pengingat
/// prioritas tertinggi ditampilkan lewat ReminderService (Seq 4.22).
/// TimerService menghitung waktu layar kontinu untuk 20-20-20 di kedua mode.
///
/// Setiap pemantauan dicatat di tabel `sessions`; selama Mode AI, metrik
/// disimpan ke `metric_samples` setiap 60 detik (KDL-01). Hanya angka yang
/// disimpan, tidak pernah frame kamera.
class MonitoringController extends Notifier<MonitoringState> {
  StreamSubscription<CameraFrame>? _sub;
  /// Detak 1 detik untuk TimerService (Mode AI & Mode Timer).
  Timer? _ticker;
  Timer? _sampleTimer;
  /// Percobaan ulang kamera tiap [CvConstants.cameraRetryInterval] (PMT-08).
  Timer? _cameraRetry;
  /// Hari (lokal) saat Hari Pemantauan AI diaktifkan; dipakai agar kembali
  /// ke Mode AI setelah kamera tersedia tidak memotong kredit lagi.
  DateTime? _activatedDay;
  bool _busy = false;
  BlinkAnalyzer? _blink;
  DistanceEstimator? _distance;
  SessionEvaluator? _evaluator;
  RuleEngine? _rules;
  late final TimerService _screenTimer = TimerService(interval: _interval202020);

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
  ReminderController get _reminders => ref.read(reminderControllerProvider.notifier);

  Duration get _interval202020 => Duration(
      minutes: state.fast202020 ? CvConstants.debugRule202020Min : _settings.interval202020Min);

  /// Ambang jarak: 30 cm di ponsel, 50 cm di desktop (§9.5).
  static double get minDistanceCm =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS
          ? CvConstants.minDistanceMobileCm
          : CvConstants.minDistanceDesktopCm;

  @override
  MonitoringState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _ticker?.cancel();
      _sampleTimer?.cancel();
      _cameraRetry?.cancel();
    });
    // Pengaturan langsung diterapkan tanpa restart (UC-21).
    ref.listen(settingsControllerProvider.select((s) => s.sensitivity), (_, next) {
      _blink?.tauFactor = next.tauFactor;
    });
    ref.listen(settingsControllerProvider.select((s) => s.interval202020Min), (_, next) {
      _applyInterval();
    });
    return MonitoringState(
        secondsToNext202020: _settings.interval202020Min * Duration.secondsPerMinute);
  }

  /// UC-09 Memulai Pemantauan AI. Hari Pemantauan AI diaktifkan lewat
  /// CreditService (§8.2, Seq 4.21); jeda lalu mulai lagi di hari yang sama
  /// tidak memotong kuota/kredit lagi (UC-10).
  Future<StartAiOutcome> startAi() async {
    if (state.mode == MonitoringMode.ai || state.starting) return StartAiOutcome.alreadyRunning;
    final calib = ref.read(calibrationControllerProvider);
    if (!calib.isComplete) {
      state = state.copyWith(message: 'Lakukan kalibrasi terlebih dahulu.');
      return StartAiOutcome.notCalibrated;
    }

    state = state.copyWith(starting: true);
    final ActivationResult activation;
    try {
      activation = await ref.read(creditControllerProvider.notifier).activateToday();
    } catch (e) {
      // Offline & hari belum aktif → Mode Timer (alur alternatif §8.2).
      // Error lain (mis. 401 sesi berakhir) juga ke Mode Timer, dengan pesan jelas.
      state = state.copyWith(starting: false);
      useTimerMode();
      final reason = e is ApiException && e is! NetworkException
          ? friendlyErrorMessage(e)
          : 'Tidak dapat mengaktifkan Hari Pemantauan AI (offline).';
      state = state.copyWith(message: '$reason Beralih ke Mode Timer.');
      return StartAiOutcome.offlineTimerMode;
    }
    switch (activation) {
      case ActivationInsufficient():
        state = state.copyWith(
            starting: false,
            message: 'Kuota gratis & kredit habis. Beli kredit atau gunakan Mode Timer.');
        return StartAiOutcome.insufficientCredit;
      case ActivationSuccess(:final source, :final alreadyActive):
        state = state.copyWith(
            message: alreadyActive
                ? 'Hari Pemantauan AI hari ini sudah aktif.'
                : source == DaySource.free
                    ? 'Hari Pemantauan AI aktif (kuota gratis).'
                    : 'Hari Pemantauan AI aktif (1 kredit terpakai).');
    }

    _activatedDay = _today();
    return _startAiPipeline();
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Kamera + analisis setelah Hari Pemantauan AI aktif (tanpa aktivasi).
  Future<StartAiOutcome> _startAiPipeline() async {
    final calib = ref.read(calibrationControllerProvider);
    await _stopEverything();
    _blink = BlinkAnalyzer(baselineEar: calib.baselineEar!, tauFactor: _settings.sensitivity.tauFactor);
    _distance = DistanceEstimator(focalLengthPx: calib.focalLengthPx!);
    _evaluator = SessionEvaluator();
    _rules = RuleEngine(minDistanceCm: minDistanceCm);

    await _analyzer.load();
    await _camera.start();
    if (_cameraBlocked) {
      await _camera.stop();
      _fallbackToTimerForCamera();
      return StartAiOutcome.cameraUnavailable;
    }
    _sub = _camera.frames.listen(_onFrame);
    state = state.copyWith(
      mode: MonitoringMode.ai,
      starting: false,
      paused: false,
      waitingForCamera: false,
      cameraActive: _camera.usingRealCamera,
      usingRealCamera: _camera.streamingRealFrames,
      analyzerName: _analyzer.name,
      sessionStart: DateTime.now(),
    );
    _beginSession(SessionMode.ai);
    _startScreenTimer();
    _guard(_metrics.purgeOld);
    _sampleTimer = Timer.periodic(MetricsRepository.sampleInterval, (_) => saveSampleNow());
    return StartAiOutcome.started;
  }

  /// Kamera ada tetapi tidak bisa dibuka (dipakai aplikasi lain / izin ditolak).
  bool get _cameraBlocked =>
      _camera.failure == CameraFailure.unavailable || _camera.failure == CameraFailure.permissionDenied;

  /// UC-09 alur alternatif: kamera dipakai aplikasi lain → Mode Timer, lalu
  /// coba lagi tiap 60 detik.
  void _fallbackToTimerForCamera() {
    final denied = _camera.failure == CameraFailure.permissionDenied;
    final seconds = CvConstants.cameraRetryInterval.inSeconds;
    useTimerMode();
    state = state.copyWith(
      starting: false,
      waitingForCamera: true,
      message: denied
          ? 'Izin kamera ditolak. Beralih ke Mode Timer; izinkan kamera, dicoba lagi tiap $seconds detik.'
          : 'Kamera sedang dipakai aplikasi lain. Beralih ke Mode Timer; dicoba lagi tiap $seconds detik.',
    );
    _cameraRetry = Timer.periodic(CvConstants.cameraRetryInterval, (_) => retryCameraNow());
  }

  /// Satu percobaan ulang kamera (dipanggil timer; publik untuk test).
  /// Berhasil di hari yang sama → kembali ke Mode AI tanpa memotong kredit.
  @visibleForTesting
  Future<bool> retryCameraNow() async {
    if (!state.waitingForCamera || state.mode != MonitoringMode.timer) {
      _cameraRetry?.cancel();
      return false;
    }
    await _camera.start();
    final ok = !_cameraBlocked;
    await _camera.stop();
    if (!ok) return false;
    if (_activatedDay != _today()) {
      // Hari berganti: aktivasi baru butuh tindakan pengguna (kuota/kredit).
      _cameraRetry?.cancel();
      state = state.copyWith(
          waitingForCamera: false, message: 'Kamera tersedia lagi. Mulai Pemantauan AI untuk hari ini.');
      return false;
    }
    final outcome = await _startAiPipeline();
    if (outcome == StartAiOutcome.started) {
      state = state.copyWith(message: 'Kamera tersedia lagi. Kembali ke Pemantauan AI.');
    }
    return outcome == StartAiOutcome.started;
  }

  /// Jeda (S-11 tray / Dashboard): kamera & waktu layar berhenti, sesi
  /// ditutup; [resume] membuka sesi baru tanpa aktivasi ulang.
  Future<void> pause() async {
    if (state.mode == MonitoringMode.idle || state.paused) return;
    _ticker?.cancel();
    _ticker = null;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _cameraRetry?.cancel();
    _cameraRetry = null;
    _reminders.closeActive();
    if (state.mode == MonitoringMode.ai) await saveSampleNow();
    await _sub?.cancel();
    _sub = null;
    await _camera.stop();
    await _endSession();
    state = state.copyWith(
        paused: true, cameraActive: false, waitingForCamera: false, message: 'Pemantauan dijeda.');
  }

  Future<void> resume() async {
    if (!state.paused) return;
    final mode = state.mode;
    if (mode == MonitoringMode.ai) {
      await _camera.start();
      if (_cameraBlocked) {
        await _camera.stop();
        _fallbackToTimerForCamera();
        return;
      }
      _blink?.reset();
      _distance?.reset();
      _sub = _camera.frames.listen(_onFrame);
      _sampleTimer = Timer.periodic(MetricsRepository.sampleInterval, (_) => saveSampleNow());
    }
    _beginSession(mode == MonitoringMode.ai ? SessionMode.ai : SessionMode.timer);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tickScreenTimer());
    state = state.copyWith(
      paused: false,
      cameraActive: mode == MonitoringMode.ai && _camera.usingRealCamera,
      message: 'Pemantauan dilanjutkan.',
    );
  }

  /// KDL-02: layar mati di ponsel → pemantauan berhenti (hemat baterai).
  Future<void> stopForScreenOff() async {
    if (state.mode == MonitoringMode.idle) return;
    await _stopEverything();
    state = state.stopped(message: 'Pemantauan dihentikan karena layar mati.');
  }

  /// UC-12 Mode Timer 20-20-20 tanpa kamera (gratis tanpa batas).
  void useTimerMode() {
    _stopEverything();
    state = state.stopped(message: state.message).copyWith(
          mode: MonitoringMode.timer,
          sessionStart: DateTime.now(),
        );
    _rules = RuleEngine(minDistanceCm: minDistanceCm);
    _beginSession(SessionMode.timer);
    _startScreenTimer();
  }

  /// UC-10 Menghentikan Pemantauan.
  Future<void> stop() async {
    await _stopEverything();
    state = state.stopped(message: 'Pemantauan dihentikan.');
  }

  /// Opsi demo hanya tersedia saat memakai DummyFaceAnalyzer.
  bool get canSimulateFatigue => _analyzer is DummyFaceAnalyzer;

  /// Hanya untuk demo: membuat analyzer tiruan meniru mata lelah.
  void setFatigueSimulation(bool on) {
    final a = _analyzer;
    if (a is DummyFaceAnalyzer) {
      a.simulateFatigue = on;
      state = state.copyWith(simulatingFatigue: on);
    }
  }

  /// Hanya untuk demo: wajah tiruan terlalu dekat ke layar.
  void setTooCloseSimulation(bool on) {
    final a = _analyzer;
    if (a is DummyFaceAnalyzer) {
      a.simulateTooClose = on;
      state = state.copyWith(simulatingTooClose: on);
    }
  }

  /// Opsi debug (hanya DummyFaceAnalyzer): interval 20-20-20 = 1 menit.
  void setFast202020(bool on) {
    if (on && !canSimulateFatigue) return;
    state = state.copyWith(fast202020: on);
    _applyInterval();
  }

  /// Waktu layar kontinu menurut TimerService.
  @visibleForTesting
  TimerService get screenTimer => _screenTimer;

  /// Satu detak TimerService (dipanggil tiap detik; publik untuk test).
  @visibleForTesting
  void tickScreenTimer() {
    final ai = state.mode == MonitoringMode.ai;
    // Mode AI: waktu layar tidak bertambah saat wajah hilang > 10 dtk (PMT-05).
    if (!(ai && state.facePaused)) _screenTimer.tick();
    state = state.copyWith(secondsToNext202020: _screenTimer.remaining.inSeconds);
    // Mode Timer: tidak ada evaluasi 10 detik, cek 20-20-20 setiap detak.
    if (state.mode == MonitoringMode.timer && _screenTimer.due) {
      _evaluateReminders(ReminderMetrics(t: DateTime.now(), rule202020Due: true));
    }
  }

  void _startScreenTimer() {
    _screenTimer
      ..interval = _interval202020
      ..reset();
    state = state.copyWith(secondsToNext202020: _screenTimer.remaining.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tickScreenTimer());
  }

  /// Interval dari Pengaturan / opsi debug langsung berlaku (UC-21).
  void _applyInterval() {
    _screenTimer.interval = _interval202020;
    state = state.copyWith(secondsToNext202020: _screenTimer.remaining.inSeconds);
  }

  /// RuleEngine → satu pengingat prioritas tertinggi → ReminderService.
  /// Cooldown hanya dimulai bila pengingat benar-benar tampil (tidak sedang
  /// ada pengingat lain, tidak ditunda / Mode Fokus).
  void _evaluateReminders(ReminderMetrics m) {
    final rules = _rules;
    if (rules == null) return;
    final top = rules.top(m);
    if (top == null || !_reminders.canShow) return;
    final shown = _reminders.show(
      top,
      session: _session,
      verifyBreak: state.mode == MonitoringMode.ai && top == ReminderType.rule202020,
      onDone: (type, action) {
        // Setelah istirahat (atau diabaikan) timer 20-20-20 direset; bila
        // ditunda, pengingat muncul lagi setelah masa tunda.
        if (type == ReminderType.rule202020 && action != AlertAction.snoozed) {
          _screenTimer.reset();
          state = state.copyWith(secondsToNext202020: _screenTimer.remaining.inSeconds);
        }
      },
    );
    if (shown) rules.markShown(top, m.t);
  }

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
    _cameraRetry?.cancel();
    _cameraRetry = null;
    final ending = _endSession();
    _sampleTimer?.cancel();
    _sampleTimer = null;
    setFatigueSimulation(false);
    setTooCloseSimulation(false);
    _ticker?.cancel();
    _ticker = null;
    _reminders.closeActive();
    _rules = null;
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
      final evaluated =
          evaluator.update(t: result.timestamp, faceDetected: result.faceDetected, blink: blink);
      // Durasi kondisi jarak/kedip dilacak per frame; keputusan tiap 10 detik.
      _rules?.observe(result.timestamp, distanceCm: distance, blinkRate: blink.blinkRate);
      _reminders.observeFace(
          t: result.timestamp, faceDetected: result.faceDetected, yawDeg: result.yawDeg);

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
      if (evaluated) {
        _evaluateReminders(ReminderMetrics(
          t: result.timestamp,
          fatigueScore: evaluator.score,
          distanceCm: distance,
          blinkRate: blink.blinkRate,
          rule202020Due: _screenTimer.due,
        ));
      }
    } finally {
      _busy = false;
    }
  }
}
