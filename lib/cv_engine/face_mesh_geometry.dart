import 'dart:math' as math;
import 'dart:typed_data';

import '../core/constants/cv_constants.dart';
import 'face_analyzer.dart';

/// Matematika murni (tanpa TFLite & tanpa UI) untuk [MediaPipeFaceAnalyzer]:
/// pemetaan frame mentah ↔ frame tegak, ROI wajah, sampling piksel ke tensor,
/// decode BlazeFace, konversi 478 landmark ke piksel, dan yaw.
///
/// Dipisah agar bisa diuji dengan data sintetis tanpa model (PML-01).
/// Semua buffer hanya hidup di memori (PRV-01).

/// Format piksel frame mentah yang didukung.
enum PixelFormat { yuv420, bgra8888 }

/// Salinan ringan (tanpa menyalin byte) dari satu frame kamera mentah.
class FrameImage {
  final int width;
  final int height;
  final PixelFormat format;
  final List<Uint8List> planes;
  final List<int> rowStrides;

  /// Jarak antar-piksel per plane (YUV420: plane U/V bernilai 1 = planar,
  /// 2 = semi-planar/NV12/NV21).
  final List<int> pixelStrides;

  const FrameImage({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
  });
}

/// Transformasi affine 2D: (u, v) → (a·u + b·v + c, d·u + e·v + f).
class Affine2 {
  final double a, b, c, d, e, f;
  const Affine2(this.a, this.b, this.c, this.d, this.e, this.f);

  double mapX(double u, double v) => a * u + b * v + c;
  double mapY(double u, double v) => d * u + e * v + f;

  /// `this ∘ inner`: terapkan [inner] dulu, lalu ini.
  Affine2 compose(Affine2 inner) => Affine2(
        a * inner.a + b * inner.d,
        a * inner.b + b * inner.e,
        a * inner.c + b * inner.f + c,
        d * inner.a + e * inner.d,
        d * inner.b + e * inner.e,
        d * inner.c + e * inner.f + f,
      );
}

/// Pemetaan koordinat frame tegak (wajah berdiri) → koordinat buffer mentah
/// kamera. [rotationDegrees] = putaran searah jarum jam yang membuat buffer
/// mentah menjadi tegak (0/90/180/270), mis. sensor kamera depan Android.
class UprightMapping {
  final int rawWidth;
  final int rawHeight;
  final int rotationDegrees;

  UprightMapping(this.rawWidth, this.rawHeight, int rotationDegrees)
      : rotationDegrees = ((rotationDegrees % 360) + 360) % 360 ~/ 90 * 90;

  bool get _swap => rotationDegrees == 90 || rotationDegrees == 270;
  int get width => _swap ? rawHeight : rawWidth;
  int get height => _swap ? rawWidth : rawHeight;

  /// Affine (x, y) tegak → (rx, ry) mentah.
  Affine2 get toRaw => switch (rotationDegrees) {
        90 => Affine2(0, 1, 0, -1, 0, rawHeight.toDouble()),
        180 => Affine2(-1, 0, rawWidth.toDouble(), 0, -1, rawHeight.toDouble()),
        270 => Affine2(0, -1, rawWidth.toDouble(), 1, 0, 0),
        _ => const Affine2(1, 0, 0, 0, 1, 0),
      };
}

/// Daerah wajah persegi yang diputar (koordinat frame tegak, piksel).
/// [angle] (radian) = arah sumbu-x potongan di frame (kemiringan kepala).
class FaceRoi {
  final double cx, cy, size, angle;
  const FaceRoi({required this.cx, required this.cy, required this.size, this.angle = 0});

  /// Seluruh frame dengan letterbox (untuk detektor).
  factory FaceRoi.wholeFrame(int width, int height) => FaceRoi(
      cx: width / 2, cy: height / 2, size: math.max(width, height).toDouble());

  /// Affine koordinat piksel potongan n×n → frame tegak.
  Affine2 cropToFrame(int n) {
    final s = size / n;
    final cs = math.cos(angle) * s, sn = math.sin(angle) * s;
    // p = c + R·((u − n/2)·s, (v − n/2)·s)
    final h = n / 2;
    return Affine2(cs, -sn, cx - cs * h + sn * h, sn, cs, cy - sn * h - cs * h);
  }

  Point2 toFrame(double u, double v, int n) {
    final m = cropToFrame(n);
    return Point2(m.mapX(u, v), m.mapY(u, v));
  }
}

/// Mengisi [out] (n×n×3, RGB, HWC) dari [img] dengan sampling bilinear (luma)
/// lewat [cropToRaw]. Nilai = byte·[scale] + [offset]; di luar frame = hitam.
void sampleToTensor(
  FrameImage img,
  Affine2 cropToRaw,
  int n,
  Float32List out, {
  required double scale,
  required double offset,
}) {
  assert(out.length >= n * n * 3);
  final w = img.width, h = img.height;
  final black = offset;
  var o = 0;
  final yuv = img.format == PixelFormat.yuv420;
  final p0 = img.planes[0];
  final rs0 = img.rowStrides[0];
  final ps0 = img.pixelStrides.isEmpty ? (yuv ? 1 : 4) : img.pixelStrides[0];
  final pu = yuv ? img.planes[1] : p0;
  final pv = yuv ? img.planes[2] : p0;
  final rsUv = yuv ? img.rowStrides[1] : 0;
  final psUv = yuv ? img.pixelStrides[1] : 0;
  for (var v = 0; v < n; v++) {
    for (var u = 0; u < n; u++) {
      final cu = u + 0.5, cv = v + 0.5;
      final rx = cropToRaw.mapX(cu, cv);
      final ry = cropToRaw.mapY(cu, cv);
      if (rx < 0 || ry < 0 || rx >= w || ry >= h) {
        out[o++] = black;
        out[o++] = black;
        out[o++] = black;
        continue;
      }
      // Bilinear pada pusat piksel.
      final px = rx - 0.5, py = ry - 0.5;
      var x0 = px.floor(), y0 = py.floor();
      final fx = px - x0, fy = py - y0;
      var x1 = x0 + 1, y1 = y0 + 1;
      if (x0 < 0) x0 = 0;
      if (y0 < 0) y0 = 0;
      if (x1 >= w) x1 = w - 1;
      if (y1 >= h) y1 = h - 1;
      double r, g, b;
      if (yuv) {
        final yv = _bilerp(p0[y0 * rs0 + x0 * ps0], p0[y0 * rs0 + x1 * ps0],
            p0[y1 * rs0 + x0 * ps0], p0[y1 * rs0 + x1 * ps0], fx, fy);
        final ix = rx.toInt() >> 1, iy = ry.toInt() >> 1;
        final uvi = iy * rsUv + ix * psUv;
        final uu = (uvi < pu.length ? pu[uvi] : 128) - 128.0;
        final vv = (uvi < pv.length ? pv[uvi] : 128) - 128.0;
        r = yv + 1.402 * vv;
        g = yv - 0.344136 * uu - 0.714136 * vv;
        b = yv + 1.772 * uu;
      } else {
        double ch(int c) => _bilerp(p0[y0 * rs0 + x0 * 4 + c], p0[y0 * rs0 + x1 * 4 + c],
            p0[y1 * rs0 + x0 * 4 + c], p0[y1 * rs0 + x1 * 4 + c], fx, fy);
        b = ch(0);
        g = ch(1);
        r = ch(2);
      }
      out[o++] = _clamp255(r) * scale + offset;
      out[o++] = _clamp255(g) * scale + offset;
      out[o++] = _clamp255(b) * scale + offset;
    }
  }
}

double _bilerp(int a, int b, int c, int d, double fx, double fy) {
  final top = a + (b - a) * fx;
  final bot = c + (d - c) * fx;
  return top + (bot - top) * fy;
}

double _clamp255(double x) => x < 0 ? 0 : (x > 255 ? 255 : x);

// ---------------------------------------------------------------------------
// BlazeFace (face_detector.tflite, short range 128×128, 896 anchor)
// ---------------------------------------------------------------------------

/// Pusat anchor SSD (ternormalisasi 0..1). Ukuran anchor tetap 1 (fixed size),
/// sesuai opsi `ssd_anchors_calculator` MediaPipe untuk detektor short range:
/// stride 8, 16, 16, 16 dengan 2 anchor per lapis → 16·16·2 + 8·8·6 = 896.
List<Point2> blazeFaceAnchors() {
  const strides = CvConstants.detectorStrides;
  const size = CvConstants.detectorInputSize;
  final anchors = <Point2>[];
  var layer = 0;
  while (layer < strides.length) {
    var last = layer;
    while (last < strides.length && strides[last] == strides[layer]) {
      last++;
    }
    final perCell = 2 * (last - layer); // aspek 1 + skala interpolasi
    final grid = (size / strides[layer]).ceil();
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        for (var k = 0; k < perCell; k++) {
          anchors.add(Point2((x + 0.5) / grid, (y + 0.5) / grid));
        }
      }
    }
    layer = last;
  }
  return anchors;
}

/// Satu deteksi wajah dalam piksel input detektor (0..128).
class FaceDetection {
  final double score;
  final double cx, cy, w, h;
  final Point2 rightEye, leftEye;
  const FaceDetection({
    required this.score,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.rightEye,
    required this.leftEye,
  });
}

double sigmoid(double x) => 1 / (1 + math.exp(-x));

/// Decode output BlazeFace: `regressors` [896×16] (x, y, w, h, 6 keypoint)
/// dan `classificators` [896] (logit). Mengembalikan wajah terbaik (skor
/// tertinggi, dihaluskan dengan rata-rata berbobot deteksi yang tumpang
/// tindih), atau null bila tidak ada skor ≥ [CvConstants.detectorScoreMin].
FaceDetection? decodeBestFace(Float32List regressors, Float32List scores, List<Point2> anchors) {
  const s = CvConstants.detectorInputSize * 1.0;
  final cands = <FaceDetection>[];
  for (var i = 0; i < anchors.length; i++) {
    final raw = scores[i].clamp(-100.0, 100.0);
    final score = sigmoid(raw);
    if (score < CvConstants.detectorScoreMin) continue;
    final o = i * 16;
    final ax = anchors[i].x * s, ay = anchors[i].y * s;
    cands.add(FaceDetection(
      score: score,
      cx: regressors[o] + ax,
      cy: regressors[o + 1] + ay,
      w: regressors[o + 2],
      h: regressors[o + 3],
      rightEye: Point2(regressors[o + 4] + ax, regressors[o + 5] + ay),
      leftEye: Point2(regressors[o + 6] + ax, regressors[o + 7] + ay),
    ));
  }
  if (cands.isEmpty) return null;
  cands.sort((a, b) => b.score.compareTo(a.score));
  final best = cands.first;
  // Rata-rata berbobot (weighted NMS) untuk klaster wajah terbaik.
  var wsum = 0.0, cx = 0.0, cy = 0.0, w = 0.0, h = 0.0, rx = 0.0, ry = 0.0, lx = 0.0, ly = 0.0;
  for (final d in cands) {
    if (_iou(best, d) < CvConstants.detectorNmsIou) continue;
    wsum += d.score;
    cx += d.cx * d.score;
    cy += d.cy * d.score;
    w += d.w * d.score;
    h += d.h * d.score;
    rx += d.rightEye.x * d.score;
    ry += d.rightEye.y * d.score;
    lx += d.leftEye.x * d.score;
    ly += d.leftEye.y * d.score;
  }
  return FaceDetection(
    score: best.score,
    cx: cx / wsum,
    cy: cy / wsum,
    w: w / wsum,
    h: h / wsum,
    rightEye: Point2(rx / wsum, ry / wsum),
    leftEye: Point2(lx / wsum, ly / wsum),
  );
}

double _iou(FaceDetection a, FaceDetection b) {
  final x0 = math.max(a.cx - a.w / 2, b.cx - b.w / 2);
  final y0 = math.max(a.cy - a.h / 2, b.cy - b.h / 2);
  final x1 = math.min(a.cx + a.w / 2, b.cx + b.w / 2);
  final y1 = math.min(a.cy + a.h / 2, b.cy + b.h / 2);
  final inter = math.max(0.0, x1 - x0) * math.max(0.0, y1 - y0);
  final union = a.w * a.h + b.w * b.h - inter;
  return union <= 0 ? 0 : inter / union;
}

/// ROI landmark dari deteksi: pusat kotak, sisi = max(w, h) × 1,5, diputar
/// mengikuti garis mata kanan → kiri (seperti graf MediaPipe).
FaceRoi roiFromDetection(FaceDetection d, FaceRoi detectorRoi) {
  const n = CvConstants.detectorInputSize;
  final c = detectorRoi.toFrame(d.cx, d.cy, n);
  final re = detectorRoi.toFrame(d.rightEye.x, d.rightEye.y, n);
  final le = detectorRoi.toFrame(d.leftEye.x, d.leftEye.y, n);
  final scale = detectorRoi.size / n;
  return FaceRoi(
    cx: c.x,
    cy: c.y,
    size: math.max(d.w, d.h) * scale * CvConstants.roiScale,
    angle: math.atan2(le.y - re.y, le.x - re.x),
  );
}

// ---------------------------------------------------------------------------
// Face landmarks (face_landmarks_detector.tflite, 256×256 → 478×3)
// ---------------------------------------------------------------------------

/// Landmark dalam ruang potongan (piksel 0..n, z skala sama dengan x).
class CropLandmarks {
  final Float32List xyz; // 478 × 3
  const CropLandmarks(this.xyz);

  int get count => xyz.length ~/ 3;
  double x(int i) => xyz[i * 3];
  double y(int i) => xyz[i * 3 + 1];
  double z(int i) => xyz[i * 3 + 2];
}

/// Mengubah landmark potongan → piksel frame tegak.
List<Point2> landmarksToFrame(CropLandmarks lm, FaceRoi roi) {
  const n = CvConstants.landmarkInputSize;
  final m = roi.cropToFrame(n);
  return List<Point2>.generate(lm.count, (i) {
    final u = lm.x(i), v = lm.y(i);
    return Point2(m.mapX(u, v), m.mapY(u, v));
  }, growable: false);
}

/// Yaw (derajat) dari kedalaman tepi pipi kanan/kiri di ruang potongan yang
/// sudah tegak (roll dihapus ROI): atan2(Δz, Δx). 0 = menghadap kamera.
double yawFromLandmarks(CropLandmarks lm) {
  const r = CvConstants.yawRightIndex, l = CvConstants.yawLeftIndex;
  final dx = lm.x(l) - lm.x(r);
  final dz = lm.z(l) - lm.z(r);
  if (dx == 0 && dz == 0) return 0;
  return math.atan2(dz, dx) * 180 / math.pi;
}

/// ROI pelacakan untuk frame berikutnya dari landmark frame ini (tanpa
/// detektor): sudut dari sudut mata luar 33 → 263, kotak pembatas di sumbu
/// yang diputar, sisi terpanjang × 1,5.
FaceRoi roiFromLandmarks(List<Point2> pts) {
  final re = pts[CvConstants.rightEye[0]];
  final le = pts[CvConstants.leftEye[3]];
  final angle = math.atan2(le.y - re.y, le.x - re.x);
  final c = math.cos(angle), s = math.sin(angle);
  var minU = double.infinity, maxU = -double.infinity;
  var minV = double.infinity, maxV = -double.infinity;
  for (final p in pts) {
    final u = p.x * c + p.y * s;
    final v = -p.x * s + p.y * c;
    if (u < minU) minU = u;
    if (u > maxU) maxU = u;
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }
  final mu = (minU + maxU) / 2, mv = (minV + maxV) / 2;
  return FaceRoi(
    cx: mu * c - mv * s,
    cy: mu * s + mv * c,
    size: math.max(maxU - minU, maxV - minV) * CvConstants.roiScale,
    angle: angle,
  );
}
