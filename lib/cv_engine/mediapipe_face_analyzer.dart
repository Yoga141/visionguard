import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/constants/cv_constants.dart';
import 'camera_source.dart';
import 'face_analyzer.dart';
import 'face_mesh_geometry.dart';

/// [FaceAnalyzer] asli: MediaPipe Face Landmarker (TFLite via `tflite_flutter`).
///
/// Pipeline per frame (DFD 3.1–3.2):
/// 1. Bila belum ada ROI pelacakan → detektor BlazeFace (128×128, letterbox
///    seluruh frame) → ROI wajah.
/// 2. Potong ROI (diputar mengikuti kemiringan kepala) langsung dari buffer
///    YUV420/BGRA ke tensor 256×256 → model landmark → 478 titik (x, y, z).
/// 3. Titik dipetakan kembali ke piksel frame tegak; yaw dari kedalaman pipi.
///    ROI frame berikutnya diturunkan dari landmark (detektor hanya dipakai
///    saat wajah hilang), seperti graf MediaPipe.
///
/// Frame hanya dibaca dari memori dan tidak pernah disimpan, di-log, atau
/// dikirim (PRV-01). Inferensi berjalan di isolate terpisah
/// ([IsolateInterpreter]) agar UI tidak tersendat; pembatasan fps dilakukan
/// [CameraSource] dan pemanggil membuang frame saat analisis masih berjalan.
class MediaPipeFaceAnalyzer implements FaceAnalyzer {
  static const detectorAsset = 'assets/models/face_detector.tflite';
  static const landmarkAsset = 'assets/models/face_landmarks_detector.tflite';

  Interpreter? _detector;
  Interpreter? _mesh;
  IsolateInterpreter? _detectorIso;
  IsolateInterpreter? _meshIso;
  Future<void>? _loading;

  late final List<Point2> _anchors = blazeFaceAnchors();
  final _detIn = Float32List(CvConstants.detectorInputSize * CvConstants.detectorInputSize * 3);
  final _meshIn = Float32List(CvConstants.landmarkInputSize * CvConstants.landmarkInputSize * 3);
  final _regressors = Float32List(CvConstants.detectorAnchorCount * 16);
  final _scores = Float32List(CvConstants.detectorAnchorCount);
  final _landmarks = Float32List(CvConstants.landmarkCount * 3);
  final _presence = Float32List(1);
  late List<Float32List> _detOuts;
  late List<Float32List> _meshOuts;
  late int _presenceIndex;

  /// ROI hasil pelacakan dari frame sebelumnya (null → jalankan detektor).
  FaceRoi? _track;

  /// Koreksi 0/180° bila orientasi sensor yang dilaporkan terbalik: dibalik
  /// setiap kali detektor gagal, dipertahankan selama wajah ditemukan.
  int _rotationFix = 0;

  bool get isLoaded => _meshIso != null;

  @override
  String get name => 'MediaPipe Face Landmarker (TFLite)';

  @override
  Future<void> load() => _loading ??= _load().catchError((Object e) {
        _loading = null;
        dispose();
        throw e;
      });

  Future<void> _load() async {
    final options = InterpreterOptions()..threads = CvConstants.inferenceThreads;
    final det = await Interpreter.fromAsset(detectorAsset, options: options);
    _detector = det;
    final mesh = await Interpreter.fromAsset(landmarkAsset, options: options);
    _mesh = mesh;

    // Verifikasi bentuk tensor agar model yang salah langsung memicu fallback.
    _expectInput(det, CvConstants.detectorInputSize);
    _expectInput(mesh, CvConstants.landmarkInputSize);
    _detOuts = _bindOutputs(det, {
      CvConstants.detectorAnchorCount * 16: _regressors,
      CvConstants.detectorAnchorCount: _scores,
    });
    final meshTensors = mesh.getOutputTensors();
    // Identity = 478×3 landmark; Identity_1 = logit kehadiran wajah (§16 #31).
    _presenceIndex = meshTensors.indexWhere((t) => t.name == 'Identity_1');
    if (_presenceIndex < 0) throw StateError('Tensor kehadiran wajah tidak ditemukan');
    _meshOuts = [
      for (var i = 0; i < meshTensors.length; i++)
        if (_count(meshTensors[i].shape) == CvConstants.landmarkCount * 3)
          _landmarks
        else if (i == _presenceIndex)
          _presence
        else
          Float32List(_count(meshTensors[i].shape)),
    ];
    if (!_meshOuts.contains(_landmarks)) throw StateError('Tensor 478 landmark tidak ditemukan');

    _detectorIso = await IsolateInterpreter.create(address: det.address);
    _meshIso = await IsolateInterpreter.create(address: mesh.address);
  }

  static int _count(List<int> shape) => shape.fold(1, (a, b) => a * b);

  static void _expectInput(Interpreter i, int size) {
    final shape = i.getInputTensor(0).shape;
    if (shape.length != 4 || shape[1] != size || shape[2] != size || shape[3] != 3) {
      throw StateError('Bentuk input model tidak sesuai: $shape');
    }
  }

  static List<Float32List> _bindOutputs(Interpreter i, Map<int, Float32List> bySize) {
    final outs = [for (final t in i.getOutputTensors()) bySize[_count(t.shape)]];
    if (outs.contains(null) || outs.length != bySize.length) {
      throw StateError('Bentuk output detektor tidak sesuai');
    }
    return outs.cast<Float32List>();
  }

  @override
  Future<FaceFrameResult> analyze(CameraFrame frame) async {
    final t = frame.timestamp;
    final image = frame.image;
    if (!isLoaded || image == null) return FaceFrameResult.noFace(t);
    final raw = frameImageFrom(image);
    if (raw == null) return FaceFrameResult.noFace(t);
    final mapping = UprightMapping(raw.width, raw.height, frame.rotationDegrees + _rotationFix);

    var roi = _track;
    if (roi == null) {
      roi = await _detect(raw, mapping);
      if (roi == null) {
        _rotationFix = (_rotationFix + 180) % 360;
        return FaceFrameResult.noFace(t);
      }
    }

    final lm = await _runLandmarks(raw, mapping, roi);
    if (lm == null) {
      _track = null;
      return FaceFrameResult.noFace(t);
    }
    final points = landmarksToFrame(lm, roi);
    _track = roiFromLandmarks(points);
    return FaceFrameResult(
      faceDetected: true,
      landmarks: points,
      yawDeg: yawFromLandmarks(lm),
      timestamp: t,
    );
  }

  Future<FaceRoi?> _detect(FrameImage raw, UprightMapping mapping) async {
    const n = CvConstants.detectorInputSize;
    final roi = FaceRoi.wholeFrame(mapping.width, mapping.height);
    sampleToTensor(raw, mapping.toRaw.compose(roi.cropToFrame(n)), n, _detIn,
        scale: 2 / 255, offset: -1);
    await _run(_detectorIso!, _detIn, _detOuts);
    final best = decodeBestFace(_regressors, _scores, _anchors);
    return best == null ? null : roiFromDetection(best, roi);
  }

  Future<CropLandmarks?> _runLandmarks(FrameImage raw, UprightMapping mapping, FaceRoi roi) async {
    const n = CvConstants.landmarkInputSize;
    sampleToTensor(raw, mapping.toRaw.compose(roi.cropToFrame(n)), n, _meshIn,
        scale: 1 / 255, offset: 0);
    await _run(_meshIso!, _meshIn, _meshOuts);
    if (sigmoid(_presence[0]) < CvConstants.facePresenceMin) return null;
    return CropLandmarks(Float32List.fromList(_landmarks));
  }

  static Future<void> _run(IsolateInterpreter iso, Float32List input, List<Float32List> outs) async {
    final buffers = <int, Object>{
      for (var i = 0; i < outs.length; i++) i: ByteData(outs[i].lengthInBytes).buffer,
    };
    await iso.runForMultipleInputs([input.buffer.asUint8List()], buffers);
    for (var i = 0; i < outs.length; i++) {
      outs[i].setAll(0, (buffers[i]! as ByteBuffer).asFloat32List());
    }
  }

  /// Membungkus [CameraImage] tanpa menyalin byte. null = format tidak didukung.
  static FrameImage? frameImageFrom(CameraImage img) {
    final planes = img.planes;
    switch (img.format.group) {
      case ImageFormatGroup.yuv420 when planes.length >= 3:
        return FrameImage(
          width: img.width,
          height: img.height,
          format: PixelFormat.yuv420,
          planes: [for (final p in planes) p.bytes],
          rowStrides: [for (final p in planes) p.bytesPerRow],
          pixelStrides: [for (final p in planes) p.bytesPerPixel ?? 1],
        );
      case ImageFormatGroup.bgra8888 when planes.isNotEmpty:
        return FrameImage(
          width: img.width,
          height: img.height,
          format: PixelFormat.bgra8888,
          planes: [planes[0].bytes],
          rowStrides: [planes[0].bytesPerRow],
          pixelStrides: const [4],
        );
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _detectorIso?.close();
    _meshIso?.close();
    _detectorIso = null;
    _meshIso = null;
    _detector?.close();
    _mesh?.close();
    _detector = null;
    _mesh = null;
    _track = null;
    _loading = null;
  }
}
