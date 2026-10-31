import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/constants/cv_constants.dart';
import 'package:visionguard/cv_engine/blink_analyzer.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/cv_engine/distance_estimator.dart';
import 'package:visionguard/cv_engine/dummy_face_analyzer.dart';
import 'package:visionguard/cv_engine/face_analyzer.dart';
import 'package:visionguard/cv_engine/fatigue_scorer.dart';
import 'package:visionguard/cv_engine/session_evaluator.dart';

/// 478 landmark sintetis dengan lebar iris [irisPx] (kanan & kiri sama).
List<Point2> landmarksWithIris(double irisPx) {
  final lm = List<Point2>.filled(CvConstants.landmarkCount, Point2.zero);
  lm[CvConstants.rightIrisA] = const Point2(100, 100);
  lm[CvConstants.rightIrisB] = Point2(100 + irisPx, 100);
  lm[CvConstants.leftIrisA] = const Point2(300, 100);
  lm[CvConstants.leftIrisB] = Point2(300 + irisPx, 100);
  return lm;
}

FaceFrameResult faceAt(DateTime t, {double irisPx = 14.04}) => FaceFrameResult(
    faceDetected: true, landmarks: landmarksWithIris(irisPx), yawDeg: 0, timestamp: t);

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

    test('lebar iris dihaluskan median 1 detik: lonjakan tunggal diabaikan (§16 #6)', () {
      final est = DistanceEstimator(focalLengthPx: 600);
      final t0 = DateTime(2026, 1, 1);
      // 14,04 px ≈ 50 cm; satu frame salah deteksi 28,08 px (≈ 25 cm).
      expect(est.update(faceAt(t0)), closeTo(50, 1e-6));
      expect(est.update(faceAt(t0.add(const Duration(milliseconds: 100)))), closeTo(50, 1e-6));
      expect(est.update(faceAt(t0.add(const Duration(milliseconds: 200)), irisPx: 28.08)),
          closeTo(50, 1e-6));
    });

    test('median hanya memakai sampel 1 detik terakhir', () {
      final est = DistanceEstimator(focalLengthPx: 600);
      final t0 = DateTime(2026, 1, 1);
      for (var i = 0; i < 10; i++) {
        est.update(faceAt(t0.add(Duration(milliseconds: 100 * i)))); // 50 cm
      }
      // Pindah ke 25 cm: setelah > 1 detik, sampel lama sudah keluar jendela.
      double? cm;
      for (var i = 0; i < 12; i++) {
        cm = est.update(faceAt(t0.add(Duration(milliseconds: 1000 + 100 * i)), irisPx: 28.08));
      }
      expect(cm, closeTo(25, 1e-6));
    });

    test('tanpa wajah → null', () {
      final est = DistanceEstimator(focalLengthPx: 600);
      expect(est.update(FaceFrameResult.noFace(DateTime(2026))), isNull);
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
      expect(scorer.score(blinkRate: 10, perclos: 0, screenMinutes: 30), 35);
    });

    test('hasil bertipe int (dibulatkan)', () {
      // 100 · (0,5·0,25 + 0,3·0 + 0,2·0,01) = 12,7 → 13
      final s = scorer.score(blinkRate: 12.5, perclos: 0, screenMinutes: 0.6);
      expect(s, isA<int>());
      expect(s, 13);
    });

    test('batas level dari CvConstants (40 dan 60)', () {
      expect(CvConstants.levelWaspadaMin, 40);
      expect(CvConstants.levelLelahMin, 60);
      expect(FatigueScorer.levelOf(39), FatigueLevel.normal);
      expect(FatigueScorer.levelOf(40), FatigueLevel.waspada);
      expect(FatigueScorer.levelOf(59), FatigueLevel.waspada);
      expect(FatigueScorer.levelOf(60), FatigueLevel.lelah);
    });
  });

  group('SessionEvaluator (PMT-04, PMT-05)', () {
    const tired = BlinkMetrics(blinkRate: 5, perclos: 0.15);
    final t0 = DateTime(2026, 1, 1);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('skor & PERCLOS hanya dievaluasi tiap 10 detik, bukan per frame (§16 #7)', () {
      final e = SessionEvaluator();
      var evaluations = 0;
      // 25 detik @ 15 fps
      for (var ms = 0; ms <= 25000; ms += 66) {
        if (e.update(t: at(ms), faceDetected: true, blink: tired)) evaluations++;
        if (ms < 10000) expect(e.score, isNull);
      }
      expect(evaluations, 2); // detik ~10 dan ~20
      expect(e.score, isA<int>());
      expect(e.score, 80); // 100·(0,5·1 + 0,3·1 + 0,2·T≈0) ≈ 80
      expect(e.perclos, 0.15);
    });

    test('wajah hilang > 10 detik → dijeda, T tidak bertambah', () {
      final e = SessionEvaluator();
      for (var ms = 0; ms <= 30000; ms += 100) {
        e.update(t: at(ms), faceDetected: true, blink: tired);
      }
      expect(e.paused, isFalse);
      final minutesBefore = e.screenMinutes;
      final scoreBefore = e.score;

      // Wajah hilang 40 detik.
      var evaluatedWhileGone = false;
      for (var ms = 30100; ms <= 70000; ms += 100) {
        if (e.update(t: at(ms), faceDetected: false, blink: const BlinkMetrics())) {
          evaluatedWhileGone = evaluatedWhileGone || ms > 40100;
        }
        if (ms <= 40000) expect(e.paused, isFalse, reason: 'baru $ms ms');
      }
      expect(e.paused, isTrue);
      expect(evaluatedWhileGone, isFalse);
      expect(e.score, scoreBefore);
      // Hanya 10 detik pertama (sebelum jeda) yang terhitung.
      expect(e.screenMinutes - minutesBefore, closeTo(10 / 60, 0.01));

      // Wajah kembali → lanjut, evaluasi berikutnya 10 detik kemudian.
      expect(e.update(t: at(70100), faceDetected: true, blink: tired), isFalse);
      expect(e.paused, isFalse);
      expect(e.update(t: at(75000), faceDetected: true, blink: tired), isFalse);
      expect(e.update(t: at(80100), faceDetected: true, blink: tired), isTrue);
    });

    test('BR tidak dilaporkan (frame valid < 70%) → skor lama dipertahankan', () {
      final e = SessionEvaluator();
      e.update(t: at(0), faceDetected: true, blink: tired);
      e.update(t: at(10000), faceDetected: true, blink: tired);
      final s = e.score;
      expect(e.update(t: at(20000), faceDetected: true, blink: const BlinkMetrics(perclos: 0.1)), isTrue);
      expect(e.score, s);
      expect(e.perclos, 0.1);
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
