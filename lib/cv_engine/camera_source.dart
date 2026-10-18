import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

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

  const CameraFrame({
    required this.width,
    required this.height,
    required this.timestamp,
    this.image,
  });
}

/// Menyalakan/mematikan kamera dan menyediakan aliran frame (SDD 4.1).
///
/// Jika kamera tidak tersedia (emulator, desktop tanpa plugin, izin ditolak),
/// kelas ini beralih ke mode simulasi yang mengirim frame kosong sesuai fps
/// target, sehingga seluruh pipeline tetap bisa didemokan.
class CameraSource {
  CameraController? _controller;
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
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      controller = CameraController(
        front,
        ResolutionPreset.medium, // ~640x480
        enableAudio: false,
      );
      await controller.initialize();
      if (!_running) {
        // stop() dipanggil selama inisialisasi.
        await controller.dispose();
        return;
      }
      _controller = controller;
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
    _frames.add(CameraFrame(width: img.width, height: img.height, timestamp: now, image: img));
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
