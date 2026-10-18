import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/constants/cv_constants.dart';
import 'package:visionguard/cv_engine/blink_analyzer.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/cv_engine/distance_estimator.dart';
import 'package:visionguard/cv_engine/dummy_face_analyzer.dart';
import 'package:visionguard/cv_engine/face_analyzer.dart';
import 'package:visionguard/cv_engine/fatigue_scorer.dart';

/// Unit test rumus SDD Bab 2.5. Jalankan: flutter test
void main() {
  group('EAR (SDD 2.5.1)', () {
    test('mata terbuka: EAR = tinggi / lebar', () {
      // lebar 30, tinggi 9 → EAR = (9 + 9) / (2·30) = 0,3
      const p = [
        Point2(0, 0), Point2(10, -4.5), Point2(20, -4.5),
        Point2(30, 0), Point2(20, 4.5), Point2(10, 4.5),
      ];
      expect(BlinkAnalyzer.eyeAspectRatio(p), closeTo(0.30, 1e-9));
    });

    test('mata tertutup: EAR mendekati 0', () {
      const p = [
        Point2(0, 0), Point2(10, 0), Point2(20, 0),
        Point2(30, 0), Point2(20, 0), Point2(10, 0),
      ];
      expect(BlinkAnalyzer.eyeAspectRatio(p), 0);
    });

    test('median untuk baseline EAR', () {
      expect(BlinkAnalyzer.median([0.3, 0.1, 0.29, 0.31, 0.3]), 0.3);
    });
  });

  group('Jarak (SDD 2.5.2)', () {
    test('d = f · 11,7 / w', () {
      // f = 600 px, w = 14,04 px → d = 500 mm
      expect(DistanceEstimator.distanceMm(600, 14.04), closeTo(500, 1e-6));
    });

    test('kalibrasi f lalu estimasi kembali ke jarak acuan', () {
      final f = DistanceEstimator.focalFromCalibration(14.04, 500);
      expect(f, closeTo(600, 1e-6));
      expect(DistanceEstimator.distanceMm(f, 14.04), closeTo(500, 1e-6));
    });

    test('fallback FOV 60° untuk frame 640 px', () {
      // (640/2) / tan(30°) ≈ 554,26
      expect(DistanceEstimator.fallbackFocal(640), closeTo(554.26, 0.01));
    });
  });

  group('Skor kelelahan (SDD 2.5.3)', () {
    const scorer = FatigueScorer();

    test('kondisi sehat → 0, Normal', () {
      final s = scorer.score(blinkRate: 18, perclos: 0, screenMinutes: 0);
      expect(s, 0);
      expect(FatigueScorer.levelOf(s), FatigueLevel.normal);
    });

    test('kondisi terburuk → 100, Lelah', () {
      final s = scorer.score(blinkRate: 4, perclos: 0.2, screenMinutes: 90);
      expect(s, 100);
      expect(FatigueScorer.levelOf(s), FatigueLevel.lelah);
    });

    test('BR 10, PERCLOS 0, 30 menit → 50·0,5 + 20·0,5 = 35', () {
      expect(scorer.score(blinkRate: 10, perclos: 0, screenMinutes: 30), closeTo(35, 1e-9));
    });

    test('batas level 40 dan 60', () {
      expect(FatigueScorer.levelOf(39.9), FatigueLevel.normal);
      expect(FatigueScorer.levelOf(40), FatigueLevel.waspada);
      expect(FatigueScorer.levelOf(60), FatigueLevel.lelah);
    });
  });

  group('Pipeline dengan DummyFaceAnalyzer', () {
    test('menghasilkan kedipan dan jarak yang masuk akal', () async {
      final analyzer = DummyFaceAnalyzer(simulatedFocalPx: 600);
      final blink = BlinkAnalyzer(baselineEar: 0.30);
      final dist = DistanceEstimator(focalLengthPx: 600);

      var t = DateTime(2026, 1, 1);
      BlinkMetrics? last;
      double? cm;
      // 60 detik @ 15 fps
      for (var i = 0; i < 900; i++) {
        t = t.add(const Duration(milliseconds: 66));
        final frame = CameraFrame(
          width: CvConstants.frameWidth,
          height: CvConstants.frameHeight,
          timestamp: t,
        );
        final r = await analyzer.analyze(frame);
        last = blink.update(r);
        cm = dist.update(r);
      }
      expect(last!.totalBlinks, greaterThan(5));
      expect(last.blinkRate, isNotNull);
      expect(cm, inInclusiveRange(35, 70));
    });
  });
}
