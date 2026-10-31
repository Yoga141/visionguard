import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/features/calibration/application/calibration_controller.dart';
import 'package:visionguard/features/calibration/data/calibration_repository.dart';
import 'package:visionguard/features/monitoring/application/monitoring_controller.dart';
import 'package:visionguard/features/monitoring/data/metrics_repository.dart';
import 'package:visionguard/features/monitoring/data/session_repository.dart';

import 'database_test.dart' show memoryDb;

/// Controller + database in-memory. Di test tidak ada plugin kamera, sehingga
/// CameraSource memakai frame simulasi (cameraId = 'simulated').
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  setUp(() {
    db = memoryDb();
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<List<Session>> allSessions() => db.select(db.sessions).get();

  group('CalibrationController', () {
    test('memuat kalibrasi tersimpan saat aplikasi dibuka', () async {
      await container.read(calibrationRepositoryProvider).save(
          cameraId: CameraSource.simulatedCameraId, earBaseline: 0.31, focalPx: 620);

      await container.read(calibrationControllerProvider.notifier).restoreSaved();
      final s = container.read(calibrationControllerProvider);
      expect(s.isComplete, isTrue);
      expect(s.baselineEar, 0.31);
      expect(s.focalLengthPx, 620);
      expect(s.cameraId, CameraSource.simulatedCameraId);
    });

    test('tanpa kalibrasi tersimpan → tetap belum terkalibrasi', () async {
      await container.read(calibrationControllerProvider.notifier).restoreSaved();
      expect(container.read(calibrationControllerProvider).isComplete, isFalse);
    });

    test('kamera diganti → minta kalibrasi ulang (KLB-04)', () async {
      await container.read(calibrationRepositoryProvider).save(
          cameraId: 'webcam-lama', earBaseline: 0.3, focalPx: 600);
      final ctrl = container.read(calibrationControllerProvider.notifier);
      await ctrl.restoreSaved(cameraId: 'webcam-lama');
      expect(container.read(calibrationControllerProvider).isComplete, isTrue);

      await ctrl.startCamera(); // kamera yang menyala: 'simulated'
      final s = container.read(calibrationControllerProvider);
      expect(s.isComplete, isFalse);
      expect(s.step, CalibrationStep.ready);
      expect(s.message, contains('Kamera berbeda'));
      await ctrl.stopCamera();
    });

    test('hasil kalibrasi disimpan ke tabel calibrations', () async {
      final ctrl = container.read(calibrationControllerProvider.notifier);
      await ctrl.startCamera();
      ctrl.startEyeCalibration();
      while (container.read(calibrationControllerProvider).step == CalibrationStep.eyeRecording) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(container.read(calibrationControllerProvider).step, CalibrationStep.eyeDone);
      ctrl.skipDistanceCalibration();
      await ctrl.stopCamera();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final saved = await container
          .read(calibrationRepositoryProvider)
          .latestFor(CameraSource.simulatedCameraId);
      final s = container.read(calibrationControllerProvider);
      expect(saved, isNotNull);
      expect(saved!.earBaseline, s.baselineEar);
      expect(saved.focalPx, s.focalLengthPx);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('MonitoringController', () {
    test('Mulai AI → baris sessions + metric_samples; Stop → ended_at', () async {
      await container.read(calibrationRepositoryProvider).save(
          cameraId: CameraSource.simulatedCameraId, earBaseline: 0.3, focalPx: 600);
      await container.read(calibrationControllerProvider.notifier).restoreSaved();

      final ctrl = container.read(monitoringControllerProvider.notifier);
      await ctrl.startAi();
      expect(container.read(monitoringControllerProvider).mode, MonitoringMode.ai);
      await Future<void>.delayed(const Duration(milliseconds: 1500)); // frame simulasi
      await ctrl.saveSampleNow();
      await ctrl.stop();

      final s = (await allSessions()).single;
      expect(s.mode, SessionMode.ai);
      expect(s.endedAt, isNotNull);
      final sample = (await container.read(metricsRepositoryProvider).samplesForSession(s.id)).single;
      expect(sample.validRatioPct, inInclusiveRange(1, 100));
      expect(sample.distanceCm, isNotNull);
    });

    test('Mode Timer → sesi timer; pindah ke AI menutup sesi timer', () async {
      await container.read(calibrationRepositoryProvider).save(
          cameraId: CameraSource.simulatedCameraId, earBaseline: 0.3, focalPx: 600);
      await container.read(calibrationControllerProvider.notifier).restoreSaved();
      final ctrl = container.read(monitoringControllerProvider.notifier);

      ctrl.useTimerMode();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await ctrl.saveSampleNow(); // Mode Timer tidak menyimpan metrik
      await ctrl.startAi();
      await ctrl.stop();

      final list = await allSessions();
      expect(list.map((s) => s.mode), [SessionMode.timer, SessionMode.ai]);
      expect(list.every((s) => s.endedAt != null), isTrue);
      expect(await db.select(db.metricSamples).get(), isEmpty);
      expect(await container.read(sessionRepositoryProvider).closeDangling(), 0);
    });
  });
}
