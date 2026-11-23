import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/cv_engine/blink_analyzer.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/cv_engine/distance_estimator.dart';
import 'package:visionguard/cv_engine/dummy_face_analyzer.dart';
import 'package:visionguard/cv_engine/face_analyzer.dart';
import 'package:visionguard/features/calibration/application/calibration_controller.dart';
import 'package:visionguard/features/calibration/data/calibration_repository.dart';
import 'package:visionguard/features/credits/data/credit_repository.dart';
import 'package:visionguard/features/eye_check/application/eye_check_controller.dart';
import 'package:visionguard/features/eye_check/application/eye_check_session.dart';

import 'database_test.dart' show memoryDb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EyeCheckSession (hitungan 2 menit)', () {
    EyeCheckSession newSession() => EyeCheckSession(
          blink: BlinkAnalyzer(baselineEar: 0.3, tauFactor: 0.7),
          distance: DistanceEstimator(focalLengthPx: 600),
        );

    test('data wajah tiruan 2 menit → BR, PERCLOS, jarak & skor wajar', () async {
      final analyzer = DummyFaceAnalyzer(simulatedFocalPx: 600);
      final session = newSession();
      final t0 = DateTime(2026, 11, 23, 9);
      for (var i = 0; i < 1200; i++) {
        // 10 fps selama 120 detik
        final t = t0.add(Duration(milliseconds: i * 100));
        session.add(await analyzer.analyze(CameraFrame(width: 640, height: 480, timestamp: t)));
      }
      final r = session.finish(duration: const Duration(minutes: 2))!;
      expect(r.validRatio, 1);
      expect(r.blinkRate, inInclusiveRange(8, 25));
      expect(r.perclos, inInclusiveRange(0, 0.15));
      expect(r.distanceCm, inInclusiveRange(38, 67));
      expect(r.score, inInclusiveRange(0, 100));
    });

    test('wajah kurang terdeteksi (< 70% frame valid) → tanpa hasil', () {
      final session = newSession();
      final t0 = DateTime(2026, 11, 23, 9);
      for (var i = 0; i < 100; i++) {
        session.add(FaceFrameResult.noFace(t0.add(Duration(milliseconds: i * 100))));
      }
      expect(session.hasEnoughFace, isFalse);
      expect(session.finish(duration: const Duration(minutes: 2)), isNull);
    });

    test('tanpa frame → tanpa hasil', () {
      expect(newSession().finish(), isNull);
    });
  });

  group('EyeCheckController (UC-11)', () {
    late AppDatabase db;
    late ProviderContainer container;
    late FakeCreditRepository credits;

    setUp(() async {
      db = memoryDb();
      credits = FakeCreditRepository();
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        creditRepositoryProvider.overrideWithValue(credits),
        eyeCheckDurationProvider.overrideWithValue(const Duration(seconds: 2)),
      ]);
      await container.read(calibrationRepositoryProvider).save(
          cameraId: CameraSource.simulatedCameraId, earBaseline: 0.3, focalPx: 600);
      await container.read(calibrationControllerProvider.notifier).restoreSaved();
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    EyeCheckController ctrl() => container.read(eyeCheckControllerProvider.notifier);
    EyeCheckState st() => container.read(eyeCheckControllerProvider);

    test('hari belum aktif → arahkan aktivasi → siap', () async {
      final sub = container.listen(eyeCheckControllerProvider, (_, __) {});
      await ctrl().prepare();
      expect(st().phase, EyeCheckPhase.needsActivation);
      await ctrl().activate();
      expect(st().phase, EyeCheckPhase.ready);
      await ctrl().prepare();
      expect(st().phase, EyeCheckPhase.ready); // hari sudah aktif
      sub.close();
    });

    test('belum kalibrasi → diminta kalibrasi', () async {
      final db2 = memoryDb();
      final c2 = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db2)]);
      addTearDown(() async {
        c2.dispose();
        await db2.close();
      });
      final sub = c2.listen(eyeCheckControllerProvider, (_, __) {});
      await c2.read(eyeCheckControllerProvider.notifier).prepare();
      expect(c2.read(eyeCheckControllerProvider).phase, EyeCheckPhase.notCalibrated);
      sub.close();
    });

    test('keluar sebelum 2 menit → batal, tidak ada yang disimpan', () async {
      final sub = container.listen(eyeCheckControllerProvider, (_, __) {});
      await ctrl().activate();
      await ctrl().start();
      expect(st().phase, EyeCheckPhase.running);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await ctrl().cancel();
      expect(st().phase, EyeCheckPhase.cancelled);
      expect(await db.select(db.sessions).get(), isEmpty);
      expect(await db.select(db.metricSamples).get(), isEmpty);
      sub.close();
    });

    test('selesai → hasil + sesi mode check & satu sampel metrik', () async {
      final sub = container.listen(eyeCheckControllerProvider, (_, __) {});
      await ctrl().activate();
      await ctrl().start();
      // Frame simulasi 10 fps; tunggu sampai hitung mundur 2 detik selesai.
      for (var i = 0; i < 40 && st().phase == EyeCheckPhase.running; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(st().phase, EyeCheckPhase.done);
      final r = st().result!;
      expect(r.distanceCm, isNotNull);

      final session = (await db.select(db.sessions).get()).single;
      expect(session.mode, SessionMode.check);
      expect(session.endedAt, isNotNull);
      final sample = (await db.select(db.metricSamples).get()).single;
      expect(sample.sessionId, session.id);
      expect(sample.fatigueScore, r.score);
      sub.close();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
