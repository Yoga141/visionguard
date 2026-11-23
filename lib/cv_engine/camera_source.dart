import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../core/constants/cv_constants.dart';

/// Satu frame yang diteruskan ke CV Engine.
///
/// [image] berisi data piksel dari plugin camera. Bernilai null pada mode
/// simulasi (tanpa kamera). Frame hanya hidup di memori dan dibuang setelah
/// dianalisis (SRS PRV-01): tidak ada penyimpanan ke disk atau jaringan.
class CameraFrame {
  final int width;
  final int height;
  final DateTime timestamp;
  final CameraImage? image;

  /// Putaran searah jarum jam (0/90/180/270) yang membuat [image] tegak.
  /// [width]/[height] tetap ukuran buffer mentah (acuan FOV kalibrasi).
  final int rotationDegrees;

  const CameraFrame({
    required this.width,
    required this.height,
    required this.timestamp,
    this.image,
    this.rotationDegrees = 0,
  });
}

/// Menyalakan/mematikan kamera dan menyediakan aliran frame (SDD 4.1).
///
/// Jika kamera tidak tersedia (emulator, desktop tanpa plugin, izin ditolak),
/// kelas ini beralih ke mode simulasi yang mengirim frame kosong sesuai fps
/// target, sehingga seluruh pipeline tetap bisa didemokan.
class CameraSource {
  /// `cameraId` untuk mode simulasi (tanpa kamera asli).
  static const simulatedCameraId = 'simulated';

  CameraController? _controller;
  CameraDescription? _description;
  String _cameraId = simulatedCameraId;
  Timer? _simTimer;
  final _frames = StreamController<CameraFrame>.broadcast();
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _running = false;
  bool _usingRealCamera = false;
  String? lastError;

  Stream<CameraFrame> get frames => _frames.stream;
  CameraController? get controller => _controller;
  bool get isRunning => _running;
  bool get usingRealCamera => _usingRealCamera;

  /// Identitas kamera yang sedang dipakai (SDD 4.1 `-cameraId`), untuk
  /// kalibrasi per kamera (KLB-04). [simulatedCameraId] bila tanpa kamera asli.
  String get cameraId => _usingRealCamera ? _cameraId : simulatedCameraId;

  /// Kamera yang akan dipakai [start], tanpa menyalakannya.
  static Future<String> resolveCameraId() async {
    try {
      final cams = await availableCameras();
      return cams.isEmpty ? simulatedCameraId : _pick(cams).name;
    } catch (_) {
      return simulatedCameraId;
    }
  }

  static CameraDescription _pick(List<CameraDescription> cams) => cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

  int get targetFps {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return isMobile ? CvConstants.targetFpsMobile : CvConstants.targetFpsDesktop;
  }

  Duration get _minInterval => Duration(milliseconds: 1000 ~/ targetFps);

  Future<void> start() async {
    if (_running) return;
    _running = true;
    CameraController? controller;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('no_camera', 'Kamera tidak ditemukan');
      final front = _pick(cams);
      controller = CameraController(
        front,
        ResolutionPreset.medium, // ~640x480
        enableAudio: false,
        // Format yang dibaca MediaPipeFaceAnalyzer (YUV420 Android, BGRA iOS).
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!_running) {
        // stop() dipanggil selama inisialisasi.
        await controller.dispose();
        return;
      }
      _controller = controller;
      _description = front;
      _cameraId = front.name;
      _usingRealCamera = true;
      lastError = null;

      // Image stream belum tersedia di semua platform. camera_windows belum
      // mendukungnya: pratinjau tetap dari kamera asli, frame analisis simulasi.
      if (controller.supportsImageStreaming()) {
        await controller.startImageStream(_onImage);
      } else {
        _startSimulatedFrames();
      }
    } catch (e) {
      lastError = e.toString();
      if (controller != null && _controller != controller) {
        try {
          await controller.dispose();
        } catch (_) {}
      }
      if (!_running) return;
      if (_controller == null) _usingRealCamera = false;
      _startSimulatedFrames();
    }
  }

  /// true jika frame yang dianalisis berasal dari kamera asli (bukan simulasi).
  bool get streamingRealFrames => _controller?.value.isStreamingImages ?? false;

  void _onImage(CameraImage img) {
    final now = DateTime.now();
    if (now.difference(_lastEmit) < _minInterval) return; // throttle ke fps target
    _lastEmit = now;
    _frames.add(CameraFrame(
      width: img.width,
      height: img.height,
      timestamp: now,
      image: img,
      rotationDegrees: _rotation(),
    ));
  }

  /// Rotasi buffer → tegak dari orientasi sensor & perangkat (Android/iOS).
  int _rotation() {
    final d = _description;
    final c = _controller;
    if (d == null || c == null) return 0;
    return frameRotation(
      sensorOrientation: d.sensorOrientation,
      front: d.lensDirection == CameraLensDirection.front,
      device: c.value.deviceOrientation,
      platform: defaultTargetPlatform,
    );
  }

  @visibleForTesting
  static int frameRotation({
    required int sensorOrientation,
    required bool front,
    required DeviceOrientation device,
    required TargetPlatform platform,
  }) {
    if (platform == TargetPlatform.iOS) return sensorOrientation % 360;
    if (platform != TargetPlatform.android) return 0;
    final dev = switch (device) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return front ? (sensorOrientation + dev) % 360 : (sensorOrientation - dev + 360) % 360;
  }

  void _startSimulatedFrames() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(_minInterval, (_) {
      _frames.add(CameraFrame(
        width: CvConstants.frameWidth,
        height: CvConstants.frameHeight,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> stop() async {
    _running = false;
    _simTimer?.cancel();
    _simTimer = null;
    final c = _controller;
    _controller = null;
    _description = null;
    _usingRealCamera = false;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) await c.stopImageStream();
      } catch (_) {}
      await c.dispose();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _frames.close();
  }
}
