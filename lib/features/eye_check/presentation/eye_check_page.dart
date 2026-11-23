import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../cv_engine/fatigue_scorer.dart';
import '../../../shared/widgets/camera_active_badge.dart';
import '../../../shared/widgets/help_button.dart';
import '../../ai_assistant/data/ai_advice_repository.dart';
import '../../ai_assistant/presentation/ai_advice_card.dart';
import '../../help/domain/help_content.dart';
import '../application/eye_check_controller.dart';
import '../application/eye_check_session.dart';

/// Teks bacaan selama sesi (S-07). Isinya sekaligus edukasi singkat.
const eyeCheckReadingText = [
  'Mata kita berkedip sekitar 15 sampai 20 kali setiap menit. Kedipan menyebarkan air mata '
      'ke seluruh permukaan mata sehingga mata tetap lembap dan nyaman.',
  'Saat menatap layar, kita cenderung lupa berkedip. Jumlah kedipan bisa turun hingga '
      'setengahnya, sehingga mata terasa kering, perih, atau lelah setelah beberapa jam.',
  'Aturan 20-20-20 membantu mengurangi beban mata: setiap 20 menit, alihkan pandangan ke '
      'benda yang berjarak sekitar 20 kaki atau 6 meter selama 20 detik.',
  'Jaga jarak layar kurang lebih satu lengan, atur kecerahan layar agar sesuai dengan '
      'cahaya ruangan, dan posisikan bagian atas layar sejajar atau sedikit di bawah mata.',
  'Minum air yang cukup, tidur teratur, dan periksakan mata secara berkala bila keluhan '
      'berlanjut. VisionGuard membantu mengingatkan, tetapi bukan pengganti dokter mata.',
];

class EyeCheckPage extends ConsumerStatefulWidget {
  const EyeCheckPage({super.key});

  @override
  ConsumerState<EyeCheckPage> createState() => _EyeCheckPageState();
}

class _EyeCheckPageState extends ConsumerState<EyeCheckPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(eyeCheckControllerProvider.notifier).prepare());
    // Aplikasi ditinggalkan / layar mati sebelum 2 menit → sesi batal (UC-11).
    _lifecycle = AppLifecycleListener(onHide: () => ref.read(eyeCheckControllerProvider.notifier).cancel());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(eyeCheckControllerProvider);
    final ctrl = ref.read(eyeCheckControllerProvider.notifier);
    final running = s.phase == EyeCheckPhase.running;

    return PopScope(
      canPop: !running,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !running) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Batalkan Sesi Cek Mata?'),
            content: const Text('Sesi belum 2 menit. Bila keluar sekarang, hasil tidak disimpan.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Lanjutkan sesi')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Batalkan')),
            ],
          ),
        );
        if (leave == true) {
          await ctrl.cancel();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sesi Cek Mata'),
          actions: [
            if (s.cameraActive && running) const CameraActiveBadge(),
            const HelpButton(topic: HelpTopic.cekMata),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ..._body(context, s, ctrl),
                  if (s.message != null) ...[
                    const SizedBox(height: 12),
                    Text(s.message!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, EyeCheckState s, EyeCheckController ctrl) {
    final theme = Theme.of(context);
    switch (s.phase) {
      case EyeCheckPhase.checking:
        return const [Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))];
      case EyeCheckPhase.notCalibrated:
        return [
          const Text('Sesi Cek Mata memakai kalibrasi mata & jarak Anda.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go(Routes.calibration), child: const Text('Kalibrasi')),
        ];
      case EyeCheckPhase.needsActivation:
        return [
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Hari Pemantauan AI belum aktif'),
              subtitle: const Text('Sesi Cek Mata memerlukan Hari Pemantauan AI yang aktif hari ini '
                  '(kuota gratis atau 1 kredit).'),
            ),
          ),
          const SizedBox(height: 12),
          if (s.insufficientCredit)
            FilledButton(onPressed: () => context.go(Routes.credits), child: const Text('Beli kredit'))
          else
            FilledButton(onPressed: ctrl.activate, child: const Text('Aktifkan hari ini')),
        ];
      case EyeCheckPhase.ready:
      case EyeCheckPhase.cancelled:
      case EyeCheckPhase.noFace:
      case EyeCheckPhase.error:
        return [
          Text('Pemeriksaan 2 menit', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Pegang ponsel seperti biasa, wajah menghadap kamera depan, lalu baca teks yang '
              'tampil dengan santai hingga hitung mundur selesai. Keluar sebelum 2 menit '
              'membatalkan sesi.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: s.phase == EyeCheckPhase.error ? ctrl.prepare : ctrl.start,
            icon: Icon(s.phase == EyeCheckPhase.error ? Icons.refresh : Icons.play_arrow),
            label: Text(s.phase == EyeCheckPhase.error ? 'Coba lagi' : 'Mulai Sesi Cek Mata'),
          ),
        ];
      case EyeCheckPhase.running:
        final mm = (s.secondsLeft ~/ 60).toString().padLeft(2, '0');
        final ss = (s.secondsLeft % 60).toString().padLeft(2, '0');
        return [
          Center(
            child: Text('$mm:$ss',
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          for (final p in eyeCheckReadingText) ...[
            Text(p, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
            const SizedBox(height: 12),
          ],
          OutlinedButton(onPressed: ctrl.cancel, child: const Text('Batalkan')),
        ];
      case EyeCheckPhase.done:
        final r = s.result!;
        return [
          _ResultCard(result: r),
          const SizedBox(height: 12),
          AiAdviceCard(
            metrics: AdviceMetrics(
              fatigueScore: r.score,
              blinkRate: r.blinkRate,
              perclos: r.perclos,
              distanceCm: r.distanceCm,
              screenMinutes: r.duration.inMinutes,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: ctrl.start, child: const Text('Ulangi')),
        ];
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final EyeCheckResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.level) {
      FatigueLevel.normal => AppTheme.normal,
      FatigueLevel.waspada => AppTheme.waspada,
      FatigueLevel.lelah => AppTheme.lelah,
    };
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Sesi Cek Mata', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Skor ${result.score} • ${result.level.label}',
                style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Kedipan: ${result.blinkRate.toStringAsFixed(1)} /menit'),
            Text('Mata tertutup (PERCLOS): ${(result.perclos * 100).toStringAsFixed(1)} %'),
            Text('Jarak rata-rata: '
                '${result.distanceCm == null ? '--' : '${result.distanceCm!.toStringAsFixed(0)} cm'}'),
          ],
        ),
      ),
    );
  }
}
