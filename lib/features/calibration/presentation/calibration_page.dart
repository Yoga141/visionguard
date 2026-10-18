import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../cv_engine/cv_providers.dart';
import '../../../shared/widgets/camera_active_badge.dart';
import '../application/calibration_controller.dart';

/// S-03 Kalibrasi (UC-07 Kalibrasi Mata, UC-08 Kalibrasi Jarak).
class CalibrationPage extends ConsumerStatefulWidget {
  const CalibrationPage({super.key});

  @override
  ConsumerState<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends ConsumerState<CalibrationPage> {
  late final CalibrationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(calibrationControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.startCamera());
  }

  @override
  void dispose() {
    // Kamera dimatikan saat keluar halaman (privasi + kamera dipakai Dashboard).
    _controller.stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(calibrationControllerProvider);
    final camera = ref.watch(cameraSourceProvider);
    final theme = Theme.of(context);
    final refCm = (CalibrationController.referenceDistanceMm / 10).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalibrasi'),
        actions: [
          if (s.usingRealCamera)
            const Padding(padding: EdgeInsets.only(right: 12), child: CameraActiveBadge())
          else if (s.step != CalibrationStep.idle && s.step != CalibrationStep.preparing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: SimulationModeBadge()),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _StepIndicator(step: s.step),
                const SizedBox(height: 16),
                _Preview(
                  controller: camera.controller,
                  usingRealCamera: s.usingRealCamera,
                  faceDetected: s.faceDetected,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('EAR langsung: ${s.liveEar?.toStringAsFixed(3) ?? '-'}'),
                    Text(s.faceDetected ? 'Wajah terdeteksi' : 'Mencari wajah...',
                        style: TextStyle(
                            color: s.faceDetected ? Colors.green : theme.colorScheme.error)),
                  ],
                ),
                const SizedBox(height: 16),
                if (s.message != null)
                  Text(s.message!, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (s.step == CalibrationStep.eyeRecording ||
                    s.step == CalibrationStep.distanceRecording)
                  LinearProgressIndicator(value: s.progress, minHeight: 8),
                const SizedBox(height: 20),
                ..._actions(context, s, refCm),
                if (s.baselineEar != null || s.focalLengthPx != null) ...[
                  const SizedBox(height: 24),
                  _ResultCard(state: s),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, CalibrationState s, int refCm) {
    switch (s.step) {
      case CalibrationStep.idle:
      case CalibrationStep.preparing:
        return const [Center(child: CircularProgressIndicator())];
      case CalibrationStep.ready:
        return [
          const Text('Langkah 1 - Kalibrasi Mata\nDuduk tegak dan tatap layar seperti biasa. '
              'Sistem merekam mata terbuka selama 10 detik untuk menentukan ambang kedipan pribadimu.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _controller.startEyeCalibration,
            icon: const Icon(Icons.remove_red_eye),
            label: const Text('Mulai Kalibrasi Mata'),
          ),
        ];
      case CalibrationStep.eyeRecording:
      case CalibrationStep.distanceRecording:
        return const [];
      case CalibrationStep.eyeDone:
        return [
          Text('Langkah 2 - Kalibrasi Jarak\nUkur $refCm cm dari layar memakai penggaris/meteran, '
              'lalu posisikan wajah pada jarak tersebut.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _controller.startDistanceCalibration,
            icon: const Icon(Icons.straighten),
            label: Text('Saya sudah di $refCm cm, mulai'),
          ),
          TextButton(
            onPressed: _controller.skipDistanceCalibration,
            child: const Text('Lewati (pakai perkiraan, kurang akurat)'),
          ),
        ];
      case CalibrationStep.done:
        return [
          FilledButton.icon(
            onPressed: () => context.go(Routes.dashboard),
            icon: const Icon(Icons.dashboard),
            label: const Text('Lanjut ke Dashboard'),
          ),
          TextButton(onPressed: _controller.reset, child: const Text('Ulangi kalibrasi')),
        ];
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final CalibrationStep step;

  @override
  Widget build(BuildContext context) {
    final eyeDone = step.index >= CalibrationStep.eyeDone.index;
    final allDone = step == CalibrationStep.done;
    Widget chip(String label, bool done, bool active) => Chip(
          avatar: Icon(done ? Icons.check_circle : Icons.circle_outlined, size: 18),
          label: Text(label),
          backgroundColor: active ? Theme.of(context).colorScheme.primaryContainer : null,
        );
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        chip('1. Mata', eyeDone, !eyeDone),
        chip('2. Jarak', allDone, eyeDone && !allDone),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller, required this.usingRealCamera, required this.faceDetected});
  final CameraController? controller;
  final bool usingRealCamera;
  final bool faceDetected;

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (usingRealCamera && c != null && c.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: _isMobile
                    // Mobile: previewSize dilaporkan landscape, layar portrait.
                    ? SizedBox(
                        width: c.value.previewSize?.height ?? 480,
                        height: c.value.previewSize?.width ?? 640,
                        child: CameraPreview(c),
                      )
                    // Desktop (Windows): tidak ada rotasi perangkat. CameraPreview
                    // menganggap orientasi portrait sehingga gambar terdistorsi,
                    // jadi tekstur pratinjau dipakai langsung pada ukuran aslinya.
                    : SizedBox(
                        width: c.value.previewSize?.width ?? 640,
                        height: c.value.previewSize?.height ?? 480,
                        child: c.buildPreview(),
                      ),
              )
            else
              Container(
                color: scheme.surfaceContainerHighest,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face_retouching_natural, size: 64),
                      SizedBox(height: 8),
                      Text('Pratinjau simulasi\n(kamera tidak tersedia)', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            // Panduan posisi wajah
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.45,
                heightFactor: 0.7,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: faceDetected ? Colors.greenAccent : Colors.white70,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.state});
  final CalibrationState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Kalibrasi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Baseline EAR (median): ${state.baselineEar?.toStringAsFixed(3) ?? '-'}'),
            Text('Ambang mata tertutup τ = 0,7 × baseline: ${state.tau?.toStringAsFixed(3) ?? '-'}'),
            Text('Focal length: ${state.focalLengthPx?.toStringAsFixed(1) ?? '-'} px'
                '${state.focalIsEstimated ? ' (perkiraan FOV 60°)' : ''}'),
          ],
        ),
      ),
    );
  }
}
