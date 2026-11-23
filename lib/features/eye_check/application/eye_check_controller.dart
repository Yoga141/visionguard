import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/cv_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_exception.dart';
import '../../../cv_engine/blink_analyzer.dart';
import '../../../cv_engine/camera_source.dart';
import '../../../cv_engine/cv_providers.dart';
import '../../../cv_engine/distance_estimator.dart';
import '../../calibration/application/calibration_controller.dart';
import '../../credits/application/credit_controller.dart';
import '../../credits/domain/credit_models.dart';
import '../../monitoring/application/monitoring_controller.dart';
import '../../monitoring/data/metrics_repository.dart';
import '../../monitoring/data/session_repository.dart';
import '../../settings/application/settings_controller.dart';
import 'eye_check_session.dart';

enum EyeCheckPhase {
  /// Memeriksa kalibrasi & status hari (`GET /credits/status`).
  checking,
  notCalibrated,

  /// Hari Pemantauan AI belum aktif → arahkan aktivasi (UC-11 alur alternatif).
  needsActivation,
  ready,
  running,
  done,

  /// Keluar sebelum 2 menit → batal, tidak disimpan.
  cancelled,

  /// Wajah kurang terdeteksi (< 70% frame valid).
  noFace,
  error,
}

@immutable
class EyeCheckState {
  const EyeCheckState({
    this.phase = EyeCheckPhase.checking,
    this.secondsLeft = 0,
    this.result,
    this.message,
    this.insufficientCredit = false,
    this.cameraActive = false,
  });

  final EyeCheckPhase phase;
  final int secondsLeft;
  final EyeCheckResult? result;
  final String? message;
  final bool insufficientCredit;
  final bool cameraActive;

  EyeCheckState copyWith({
    EyeCheckPhase? phase,
    int? secondsLeft,
    EyeCheckResult? result,
    String? message,
    bool? insufficientCredit,
    bool? cameraActive,
  }) =>
      EyeCheckState(
        phase: phase ?? this.phase,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        result: result ?? this.result,
        message: message,
        insufficientCredit: insufficientCredit ?? this.insufficientCredit,
        cameraActive: cameraActive ?? this.cameraActive,
      );
}

/// Durasi sesi (bisa dipersingkat di test).
final eyeCheckDurationProvider = Provider<Duration>((ref) => CvConstants.eyeCheckDuration);

final eyeCheckControllerProvider =
    NotifierProvider.autoDispose<EyeCheckController, EyeCheckState>(EyeCheckController.new);

/// UC-11 Sesi Cek Mata (mobile, PMT-07): cek status hari → teks bacaan +
/// hitung mundur 2 menit → BR, PERCLOS, jarak rata-rata → skor + saran.
/// Hasil disimpan sebagai `sessions.mode = 'check'` + satu baris
/// `metric_samples`; dibatalkan → tidak ada yang ditulis.
class EyeCheckController extends AutoDisposeNotifier<EyeCheckState> {
  StreamSubscription<CameraFrame>? _sub;
  Timer? _ticker;
  EyeCheckSession? _session;
  DateTime? _startedAt;
  bool _busy = false;

  CameraSource get _camera => ref.read(cameraSourceProvider);

  @override
  EyeCheckState build() {
    ref.onDispose(() {
      if (state.phase == EyeCheckPhase.running) unawaited(_teardown());
    });
    return const EyeCheckState();
  }

  /// Dipanggil saat layar dibuka.
  Future<void> prepare() async {
    if (!ref.read(calibrationControllerProvider).isComplete) {
      state = const EyeCheckState(
          phase: EyeCheckPhase.notCalibrated, message: 'Lakukan kalibrasi terlebih dahulu.');
      return;
    }
    state = const EyeCheckState(phase: EyeCheckPhase.checking);
    final credits = ref.read(creditControllerProvider.notifier);
    await credits.refresh();
    final status = ref.read(creditControllerProvider).status;
    if (status == null) {
      state = const EyeCheckState(
          phase: EyeCheckPhase.error,
          message: 'Status hari tidak dapat diperiksa. Periksa koneksi lalu coba lagi.');
      return;
    }
    state = EyeCheckState(phase: status.todayActive ? EyeCheckPhase.ready : EyeCheckPhase.needsActivation);
  }

  /// Mengaktifkan Hari Pemantauan AI (§8.2) agar sesi bisa dimulai.
  Future<void> activate() async {
    try {
      final r = await ref.read(creditControllerProvider.notifier).activateToday();
      state = switch (r) {
        ActivationSuccess() => const EyeCheckState(phase: EyeCheckPhase.ready),
        ActivationInsufficient() => const EyeCheckState(
            phase: EyeCheckPhase.needsActivation,
            insufficientCredit: true,
            message: 'Kuota gratis & kredit habis. Beli kredit untuk memakai Sesi Cek Mata.'),
      };
    } catch (e) {
      state = EyeCheckState(
          phase: EyeCheckPhase.needsActivation,
          message: e is ApiException ? friendlyErrorMessage(e) : 'Aktivasi gagal. Coba lagi.');
    }
  }

  Future<void> start() async {
    if (state.phase != EyeCheckPhase.ready && state.phase != EyeCheckPhase.noFace &&
        state.phase != EyeCheckPhase.cancelled && state.phase != EyeCheckPhase.done) {
      return;
    }
    final calib = ref.read(calibrationControllerProvider);
    // Kamera hanya bisa dipakai satu pihak: pemantauan yang berjalan dihentikan.
    await ref.read(monitoringControllerProvider.notifier).stop();
    final analyzer = ref.read(faceAnalyzerProvider);
    await analyzer.load();
    await _camera.start();
    if (_camera.failure == CameraFailure.unavailable ||
        _camera.failure == CameraFailure.permissionDenied) {
      await _camera.stop();
      state = const EyeCheckState(
          phase: EyeCheckPhase.error,
          message: 'Kamera tidak dapat dibuka (dipakai aplikasi lain atau izin ditolak).');
      return;
    }
    _session = EyeCheckSession(
      blink: BlinkAnalyzer(
          baselineEar: calib.baselineEar!,
          tauFactor: ref.read(settingsControllerProvider).sensitivity.tauFactor),
      distance: DistanceEstimator(focalLengthPx: calib.focalLengthPx!),
    );
    _startedAt = DateTime.now();
    final total = ref.read(eyeCheckDurationProvider);
    state = EyeCheckState(
        phase: EyeCheckPhase.running,
        secondsLeft: total.inSeconds,
        cameraActive: _camera.usingRealCamera);
    _sub = _camera.frames.listen((frame) async {
      if (_busy) return;
      _busy = true;
      try {
        final r = await analyzer.analyze(frame);
        _session?.add(r);
      } finally {
        _busy = false;
      }
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick(total));
  }

  void _tick(Duration total) {
    final elapsed = DateTime.now().difference(_startedAt!);
    final left = total.inSeconds - elapsed.inSeconds;
    if (left <= 0) {
      unawaited(_complete(total));
    } else {
      state = state.copyWith(secondsLeft: left);
    }
  }

  Future<void> _complete(Duration total) async {
    if (state.phase != EyeCheckPhase.running) return;
    final session = _session;
    final startedAt = _startedAt!;
    await _teardown();
    final result = session?.finish(duration: total);
    if (result == null) {
      state = const EyeCheckState(
          phase: EyeCheckPhase.noFace,
          message: 'Wajah kurang terdeteksi. Perbaiki pencahayaan & posisi, lalu ulangi.');
      return;
    }
    await _save(result, startedAt);
    state = EyeCheckState(phase: EyeCheckPhase.done, result: result);
  }

  /// Keluar sebelum 2 menit → batal; tidak ada data yang disimpan.
  Future<void> cancel() async {
    if (state.phase != EyeCheckPhase.running) return;
    await _teardown();
    state = const EyeCheckState(
        phase: EyeCheckPhase.cancelled, message: 'Sesi dibatalkan sebelum 2 menit dan tidak disimpan.');
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    await _sub?.cancel();
    _sub = null;
    await _camera.stop();
    _session = null;
  }

  Future<void> _save(EyeCheckResult r, DateTime startedAt) async {
    try {
      final sessions = ref.read(sessionRepositoryProvider);
      final id = await sessions.start(SessionMode.check, at: startedAt);
      final end = startedAt.add(r.duration);
      await ref.read(metricsRepositoryProvider).saveSample(MetricsSnapshot(
            sessionId: id,
            ts: end,
            blinkRate: r.blinkRate,
            perclos: r.perclos,
            distanceCm: r.distanceCm,
            fatigueScore: r.score,
            validRatioPct: (r.validRatio * 100).round(),
          ));
      await sessions.end(id, at: end);
    } catch (e) {
      debugPrint('Gagal menyimpan Sesi Cek Mata: $e');
    }
  }
}
