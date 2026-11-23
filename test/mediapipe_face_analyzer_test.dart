import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/constants/cv_constants.dart';
import 'package:visionguard/cv_engine/blink_analyzer.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/cv_engine/cv_providers.dart';
import 'package:visionguard/cv_engine/distance_estimator.dart';
import 'package:visionguard/cv_engine/dummy_face_analyzer.dart';
import 'package:visionguard/cv_engine/face_analyzer.dart';
import 'package:visionguard/cv_engine/face_mesh_geometry.dart';
import 'package:visionguard/cv_engine/mediapipe_face_analyzer.dart';

const _n = CvConstants.landmarkInputSize;

/// Landmark potongan sintetis: mata (EAR = [ear]) dan iris lebar [irisPx]
/// pada ruang 256×256, pipi kanan/kiri pada kedalaman sesuai [yawDeg].
CropLandmarks syntheticCrop({double ear = 0.3, double irisPx = 20, double yawDeg = 0}) {
  // Titik lain di pusat potongan (bukan 0,0) agar kotak pembatas realistis.
  final xyz = Float32List(CvConstants.landmarkCount * 3)..fillRange(0, CvConstants.landmarkCount * 3, 128);
  for (var i = 2; i < xyz.length; i += 3) {
    xyz[i] = 0;
  }
  void put(int i, double x, double y, [double z = 0]) {
    xyz[i * 3] = x;
    xyz[i * 3 + 1] = y;
    xyz[i * 3 + 2] = z;
  }

  void eye(List<int> idx, double cx, double cy) {
    const w = 50.0;
    final h = w * ear; // EAR = h / w untuk p2-p6 = p3-p5 = h
    put(idx[0], cx - w / 2, cy);
    put(idx[1], cx - w / 6, cy - h / 2);
    put(idx[2], cx + w / 6, cy - h / 2);
    put(idx[3], cx + w / 2, cy);
    put(idx[4], cx + w / 6, cy + h / 2);
    put(idx[5], cx - w / 6, cy + h / 2);
  }

  eye(CvConstants.rightEye, 90, 110);
  eye(CvConstants.leftEye, 166, 110);
  put(CvConstants.rightIrisA, 90 - irisPx / 2, 110);
  put(CvConstants.rightIrisB, 90 + irisPx / 2, 110);
  put(CvConstants.leftIrisA, 166 - irisPx / 2, 110);
  put(CvConstants.leftIrisB, 166 + irisPx / 2, 110);
  // Pipi pada jari-jari 80 px, kepala diputar yaw di sekitar sumbu vertikal.
  final a = yawDeg * math.pi / 180;
  put(CvConstants.yawRightIndex, 128 - 80 * math.cos(a), 128, -80 * math.sin(a));
  put(CvConstants.yawLeftIndex, 128 + 80 * math.cos(a), 128, 80 * math.sin(a));
  return CropLandmarks(xyz);
}

FrameImage solidYuv(int w, int h, {int y = 200, int u = 128, int v = 128}) => FrameImage(
      width: w,
      height: h,
      format: PixelFormat.yuv420,
      planes: [
        Uint8List(w * h)..fillRange(0, w * h, y),
        Uint8List((w ~/ 2) * (h ~/ 2))..fillRange(0, (w ~/ 2) * (h ~/ 2), u),
        Uint8List((w ~/ 2) * (h ~/ 2))..fillRange(0, (w ~/ 2) * (h ~/ 2), v),
      ],
      rowStrides: [w, w ~/ 2, w ~/ 2],
      pixelStrides: const [1, 1, 1],
    );

class _FailingAnalyzer implements FaceAnalyzer {
  bool disposed = false;
  @override
  Future<void> load() async => throw StateError('model hilang');
  @override
  Future<FaceFrameResult> analyze(CameraFrame frame) async => FaceFrameResult.noFace(frame.timestamp);
  @override
  void dispose() => disposed = true;
  @override
  String get name => 'gagal';
}

class _OkAnalyzer extends _FailingAnalyzer {
  @override
  Future<void> load() async {}
}

void main() {
  group('UprightMapping', () {
    test('0°: identitas', () {
      final m = UprightMapping(640, 480, 0);
      expect((m.width, m.height), (640, 480));
      expect(m.toRaw.mapX(10, 20), 10);
      expect(m.toRaw.mapY(10, 20), 20);
    });

    test('90°/270°: lebar & tinggi tertukar, sudut tegak ↔ mentah', () {
      final m90 = UprightMapping(640, 480, 90);
      expect((m90.width, m90.height), (480, 640));
      // Kiri-atas tegak = kiri-bawah mentah.
      expect(m90.toRaw.mapX(0, 0), 0);
      expect(m90.toRaw.mapY(0, 0), 480);
      final m270 = UprightMapping(640, 480, 270);
      expect((m270.width, m270.height), (480, 640));
      expect(m270.toRaw.mapX(0, 0), 640);
      expect(m270.toRaw.mapY(0, 0), 0);
      // 450° dinormalkan ke 90°.
      expect(UprightMapping(640, 480, 450).rotationDegrees, 90);
    });

    test('180°: titik dicerminkan dua sumbu', () {
      final m = UprightMapping(640, 480, 180);
      expect(m.toRaw.mapX(40, 30), 600);
      expect(m.toRaw.mapY(40, 30), 450);
    });
  });

  group('FaceRoi', () {
    test('pusat potongan = pusat ROI; sudut diputar mengikuti angle', () {
      const roi = FaceRoi(cx: 300, cy: 200, size: 256, angle: math.pi / 2);
      final c = roi.toFrame(_n / 2, _n / 2, _n);
      expect(c.x, closeTo(300, 1e-9));
      expect(c.y, closeTo(200, 1e-9));
      // Sumbu-x potongan menunjuk ke bawah frame saat angle 90°.
      final p = roi.toFrame(_n / 2 + 10, _n / 2, _n);
      expect(p.x, closeTo(300, 1e-9));
      expect(p.y, closeTo(210, 1e-9));
    });

    test('wholeFrame = letterbox persegi sisi terpanjang', () {
      final roi = FaceRoi.wholeFrame(640, 480);
      expect(roi.size, 640);
      final tl = roi.toFrame(0, 0, 128);
      expect(tl.x, 0);
      expect(tl.y, -80); // 80 px letterbox atas
    });
  });

  group('BlazeFace', () {
    test('anchor = 896 (16·16·2 + 8·8·6)', () {
      final a = blazeFaceAnchors();
      expect(a.length, CvConstants.detectorAnchorCount);
      expect(a.first.x, closeTo(0.5 / 16, 1e-9));
      expect(a[512].x, closeTo(0.5 / 8, 1e-9));
      expect(a.last.x, closeTo(7.5 / 8, 1e-9));
    });

    test('decode: skor di bawah ambang → null', () {
      final anchors = blazeFaceAnchors();
      final scores = Float32List(896)..fillRange(0, 896, -5);
      expect(decodeBestFace(Float32List(896 * 16), scores, anchors), isNull);
    });

    test('decode: offset relatif anchor, rata-rata berbobot yang tumpang tindih', () {
      final anchors = blazeFaceAnchors();
      final reg = Float32List(896 * 16);
      final scores = Float32List(896)..fillRange(0, 896, -10);
      // Dua anchor di sel yang sama (pusat sama), kotak 40×40.
      for (final i in [100, 101]) {
        reg[i * 16 + 2] = 40;
        reg[i * 16 + 3] = 40;
        reg[i * 16 + 4] = -10; // mata kanan
        reg[i * 16 + 6] = 10; // mata kiri
      }
      reg[100 * 16] = 2; // geser x +2
      scores[100] = 3;
      scores[101] = 3;
      final d = decodeBestFace(reg, scores, anchors)!;
      final ax = anchors[100].x * 128;
      expect(d.cx, closeTo(ax + 1, 1e-6)); // rata-rata (2 + 0) / 2
      expect(d.w, closeTo(40, 1e-6));
      expect(d.score, closeTo(sigmoid(3), 1e-9));
      expect(d.leftEye.x - d.rightEye.x, closeTo(20, 1e-6));
    });

    test('roiFromDetection: skala letterbox × 1,5 dan sudut dari garis mata', () {
      const det = FaceDetection(
        score: 0.9,
        cx: 64,
        cy: 64,
        w: 20,
        h: 24,
        rightEye: Point2(58, 60),
        leftEye: Point2(70, 66),
      );
      final roi = roiFromDetection(det, FaceRoi.wholeFrame(640, 480));
      expect(roi.cx, closeTo(320, 1e-9));
      expect(roi.cy, closeTo(240, 1e-9));
      expect(roi.size, closeTo(24 * 5 * 1.5, 1e-9));
      expect(roi.angle, closeTo(math.atan2(6, 12), 1e-9));
    });
  });

  group('Konversi landmark → FaceFrameResult', () {
    test('EAR tidak berubah oleh skala & rotasi ROI; iris diskalakan ke piksel frame', () {
      final crop = syntheticCrop(ear: 0.3, irisPx: 20);
      const roi = FaceRoi(cx: 320, cy: 240, size: 128, angle: 0.4);
      final pts = landmarksToFrame(crop, roi);
      expect(pts.length, CvConstants.landmarkCount);
      expect(BlinkAnalyzer.averageEar(pts), closeTo(0.3, 1e-6));
      // 20 px di potongan 256 → 10 px di ROI 128.
      expect(DistanceEstimator.irisWidthPx(pts), closeTo(10, 1e-6));
    });

    test('mata tertutup menurunkan EAR', () {
      final pts = landmarksToFrame(syntheticCrop(ear: 0.05), const FaceRoi(cx: 0, cy: 0, size: 256));
      expect(BlinkAnalyzer.averageEar(pts), closeTo(0.05, 1e-6));
    });

    test('yaw dari kedalaman pipi; > 30° → frame tidak valid', () {
      expect(yawFromLandmarks(syntheticCrop()), closeTo(0, 1e-6));
      expect(yawFromLandmarks(syntheticCrop(yawDeg: 20)), closeTo(20, 1e-3));
      expect(yawFromLandmarks(syntheticCrop(yawDeg: -45)), closeTo(-45, 1e-3));
      FaceFrameResult result(double yaw) => FaceFrameResult(
            faceDetected: true,
            landmarks: landmarksToFrame(syntheticCrop(yawDeg: yaw), const FaceRoi(cx: 0, cy: 0, size: 256)),
            yawDeg: yawFromLandmarks(syntheticCrop(yawDeg: yaw)),
            timestamp: DateTime(2026),
          );
      expect(BlinkAnalyzer.isValidFrame(result(10)), isTrue);
      expect(BlinkAnalyzer.isValidFrame(result(35)), isFalse);
    });

    test('roiFromLandmarks: ROI pelacakan mengikuti posisi & kemiringan wajah', () {
      const roi = FaceRoi(cx: 300, cy: 200, size: 200, angle: 0.3);
      final pts = landmarksToFrame(syntheticCrop(), roi);
      final next = roiFromLandmarks(pts);
      expect(next.angle, closeTo(0.3, 1e-6)); // mata sejajar di potongan
      // Titik sintetis berpusat di potongan → pusat ROI baru dekat pusat lama.
      expect((next.cx - 300).abs(), lessThan(20));
      expect((next.cy - 200).abs(), lessThan(20));
      expect(next.size, greaterThan(0));
    });
  });

  group('sampleToTensor', () {
    test('YUV abu-abu → RGB sama, normalisasi [0, 1]; di luar frame hitam', () {
      final img = solidYuv(64, 48, y: 200);
      final out = Float32List(8 * 8 * 3);
      // Potongan 8×8 yang separuh kirinya di luar frame (x < 0).
      final m = const Affine2(4, 0, -16, 0, 4, 0);
      sampleToTensor(img, m, 8, out, scale: 1 / 255, offset: 0);
      expect(out[0], 0); // piksel (0,0) → rx = −14 → hitam
      final last = (8 * 8 - 1) * 3;
      expect(out[last], closeTo(200 / 255, 1e-6));
      expect(out[last + 1], closeTo(200 / 255, 1e-6));
      expect(out[last + 2], closeTo(200 / 255, 1e-6));
    });

    test('YUV berwarna: V tinggi → merah; normalisasi [−1, 1]', () {
      final img = solidYuv(16, 16, y: 128, u: 128, v: 228);
      final out = Float32List(2 * 2 * 3);
      sampleToTensor(img, const Affine2(8, 0, 0, 0, 8, 0), 2, out, scale: 2 / 255, offset: -1);
      expect(out[0], greaterThan(out[1])); // R > G
      expect(out[0], greaterThan(out[2])); // R > B
      expect(out[0], lessThanOrEqualTo(1));
    });

    test('BGRA: urutan kanal dibalik ke RGB, mengikuti rowStride', () {
      const w = 4, h = 2, stride = 20; // stride > w·4 (padding baris)
      final bytes = Uint8List(stride * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          bytes.setAll(y * stride + x * 4, [10, 20, 30, 255]); // B, G, R, A
        }
      }
      final img = FrameImage(
          width: w,
          height: h,
          format: PixelFormat.bgra8888,
          planes: [bytes],
          rowStrides: const [stride],
          pixelStrides: const [4]);
      final out = Float32List(3);
      sampleToTensor(img, const Affine2(4, 0, 0, 0, 2, 0), 1, out, scale: 1, offset: 0);
      expect(out, [30, 20, 10]);
    });

    test('rotasi 90° mengambil piksel dari posisi mentah yang benar', () {
      // Mentah 4×2: kolom x = 0 terang, sisanya gelap.
      const w = 4, h = 2;
      final y = Uint8List(w * h);
      for (var r = 0; r < h; r++) {
        y[r * w] = 250;
      }
      final img = FrameImage(
          width: w,
          height: h,
          format: PixelFormat.yuv420,
          planes: [y, Uint8List(4)..fillRange(0, 4, 128), Uint8List(4)..fillRange(0, 4, 128)],
          rowStrides: const [w, 2, 2],
          pixelStrides: const [1, 1, 1]);
      final m = UprightMapping(w, h, 90); // tegak 2×4; baris atas tegak = x mentah 0
      final out = Float32List(2 * 4 * 3);
      sampleToTensor(img, m.toRaw.compose(const Affine2(1, 0, 0, 0, 1, 0)), 2, out,
          scale: 1, offset: 0);
      expect(out[0], greaterThan(200)); // tegak (0,0)
      expect(out[2 * 3 + 0], lessThan(130)); // tegak (0,1) → x mentah 1 (gelap)
    });
  });

  group('MediaPipeFaceAnalyzer tanpa model', () {
    test('belum dimuat / frame tanpa gambar → noFace (tidak crash)', () async {
      final a = MediaPipeFaceAnalyzer();
      expect(a.isLoaded, isFalse);
      final r = await a.analyze(CameraFrame(width: 640, height: 480, timestamp: DateTime(2026)));
      expect(r.faceDetected, isFalse);
      expect(BlinkAnalyzer.isValidFrame(r), isFalse);
      a.dispose();
    });
  });

  group('Pemilihan analyzer & fallback', () {
    test('Windows → mode simulasi dengan alasan; opsi demo tetap ada', () async {
      final a = await selectFaceAnalyzer(platform: TargetPlatform.windows, underTest: false);
      expect(a, isA<DummyFaceAnalyzer>());
      expect(a.name, contains('Mode simulasi'));
      expect(a.name, contains('image stream'));
    });

    test('Android + model gagal dimuat → mode simulasi, analyzer gagal di-dispose', () async {
      final failing = _FailingAnalyzer();
      final a = await selectFaceAnalyzer(
          platform: TargetPlatform.android, underTest: false, createMediaPipe: () => failing);
      expect(a, isA<DummyFaceAnalyzer>());
      expect(a.name, contains('gagal dimuat'));
      expect(failing.disposed, isTrue);
    });

    test('Android + model termuat → analyzer MediaPipe dipakai', () async {
      final ok = _OkAnalyzer();
      final a = await selectFaceAnalyzer(
          platform: TargetPlatform.android, underTest: false, createMediaPipe: () => ok);
      expect(identical(a, ok), isTrue);
    });

    test('di bawah flutter test → selalu dummy', () async {
      expect(await selectFaceAnalyzer(platform: TargetPlatform.android), isA<DummyFaceAnalyzer>());
    });
  });

  group('CameraSource.frameRotation', () {
    test('Android depan potret = orientasi sensor; lanskap ditambah', () {
      int rot(DeviceOrientation o, {bool front = true}) => CameraSource.frameRotation(
          sensorOrientation: 270, front: front, device: o, platform: TargetPlatform.android);
      expect(rot(DeviceOrientation.portraitUp), 270);
      expect(rot(DeviceOrientation.landscapeLeft), 0);
      expect(rot(DeviceOrientation.portraitUp, front: false), 270);
      expect(rot(DeviceOrientation.landscapeLeft, front: false), 180);
    });

    test('desktop tidak diputar', () {
      expect(
          CameraSource.frameRotation(
              sensorOrientation: 90,
              front: true,
              device: DeviceOrientation.portraitUp,
              platform: TargetPlatform.windows),
          0);
    });
  });
}
