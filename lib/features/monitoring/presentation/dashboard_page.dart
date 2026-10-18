import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../cv_engine/fatigue_scorer.dart';
import '../../../shared/widgets/camera_active_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../../calibration/application/calibration_controller.dart';
import '../application/monitoring_controller.dart';

/// S-04 Dashboard: tombol Mulai/Stop, BR, jarak, meteran skor, status kredit.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(monitoringControllerProvider);
    final ctrl = ref.read(monitoringControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final calibrated = ref.watch(calibrationControllerProvider).isComplete;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (m.cameraActive)
            const CameraActiveBadge()
          else if (m.mode == MonitoringMode.ai)
            const Center(child: SimulationModeBadge()),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'calib') {
                await ctrl.stop();
                if (context.mounted) context.go(Routes.calibration);
              } else if (v == 'logout') {
                await ctrl.stop();
                ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go(Routes.login);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'calib', child: Text('Kalibrasi ulang')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Halo, ${auth.userName ?? 'Pengguna'} 👋', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_modeLabel(m), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                _ScoreMeter(score: m.fatigueScore, level: m.level, mode: m.mode),
                const SizedBox(height: 16),
                if (m.mode == MonitoringMode.timer)
                  _TimerCard(seconds: m.secondsToNext202020)
                else
                  _MetricsGrid(state: m),
                const SizedBox(height: 16),
                _StartStopButton(state: m, calibrated: calibrated, ctrl: ctrl),
                if (m.message != null) ...[
                  const SizedBox(height: 12),
                  Text(m.message!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                _CreditCard(state: m, onAddDemoCredit: ctrl.addDemoCredit),
                if (m.mode == MonitoringMode.ai && ctrl.canSimulateFatigue) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Simulasi mata lelah (demo)'),
                    subtitle: const Text('Kedipan jarang & mata sering tertutup lama'),
                    value: m.simulatingFatigue,
                    onChanged: ctrl.setFatigueSimulation,
                  ),
                ],
                if (m.mode == MonitoringMode.ai) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Mesin deteksi: ${m.analyzerName} • '
                    'Sumber frame: ${m.usingRealCamera ? 'kamera asli' : 'simulasi'}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _modeLabel(MonitoringState m) => switch (m.mode) {
        MonitoringMode.idle => 'Pemantauan belum berjalan.',
        MonitoringMode.ai => 'Pemantauan AI berjalan.',
        MonitoringMode.timer => 'Mode Timer 20-20-20 (tanpa kamera).',
      };
}

class _ScoreMeter extends StatelessWidget {
  const _ScoreMeter({required this.score, required this.level, required this.mode});
  final double? score;
  final FatigueLevel? level;
  final MonitoringMode mode;

  Color _color(FatigueLevel? l) => switch (l) {
        FatigueLevel.normal => AppTheme.normal,
        FatigueLevel.waspada => AppTheme.waspada,
        FatigueLevel.lelah => AppTheme.lelah,
        null => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(level);
    final label = mode != MonitoringMode.ai
        ? 'Tidak ada data'
        : (level?.label ?? 'Mengumpulkan data...');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (score ?? 0) / 100,
                    strokeWidth: 10,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                  Center(
                    child: Text(
                      score?.toStringAsFixed(0) ?? '--',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Skor Kelelahan Mata'),
                  const SizedBox(height: 4),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('0–39 Normal • 40–59 Waspada • 60–100 Lelah',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.state});
  final MonitoringState state;

  @override
  Widget build(BuildContext context) {
    String f(double? v, int d) => v == null ? '--' : v.toStringAsFixed(d);
    final tiles = [
      _Metric(icon: Icons.remove_red_eye_outlined, label: 'Blink rate', value: f(state.blinkRate, 1), unit: '/menit'),
      _Metric(icon: Icons.straighten, label: 'Jarak ke layar', value: f(state.distanceCm, 0), unit: 'cm'),
      _Metric(
          icon: Icons.visibility_off_outlined,
          label: 'PERCLOS',
          value: state.perclos == null ? '--' : (state.perclos! * 100).toStringAsFixed(1),
          unit: '%'),
      _Metric(icon: Icons.analytics_outlined, label: 'EAR', value: f(state.ear, 3), unit: ''),
      _Metric(icon: Icons.touch_app_outlined, label: 'Total kedipan', value: '${state.totalBlinks}', unit: ''),
      _Metric(
          icon: Icons.timer_outlined,
          label: 'Menatap layar',
          value: state.mode == MonitoringMode.ai ? state.screenMinutes.toStringAsFixed(1) : '--',
          unit: 'menit'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 520 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: tiles,
      );
    });
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value, required this.unit});
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            ]),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              TextSpan(text: ' $unit'),
            ])),
          ],
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Pengingat 20-20-20 berikutnya'),
            const SizedBox(height: 8),
            Text('$mm:$ss',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  const _StartStopButton({required this.state, required this.calibrated, required this.ctrl});
  final MonitoringState state;
  final bool calibrated;
  final MonitoringController ctrl;

  @override
  Widget build(BuildContext context) {
    if (state.starting) {
      return const FilledButton(onPressed: null, child: Text('Menyiapkan kamera...'));
    }
    if (state.mode != MonitoringMode.idle) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppTheme.lelah),
        onPressed: ctrl.stop,
        icon: const Icon(Icons.stop),
        label: const Text('Stop'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: calibrated ? ctrl.startAi : () => context.go(Routes.calibration),
          icon: Icon(calibrated ? Icons.play_arrow : Icons.tune),
          label: Text(calibrated ? 'Mulai Pemantauan AI' : 'Kalibrasi dulu'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ctrl.useTimerMode,
          icon: const Icon(Icons.timer),
          label: const Text('Mode Timer (tanpa kamera)'),
        ),
      ],
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.state, required this.onAddDemoCredit});
  final MonitoringState state;
  final VoidCallback onAddDemoCredit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text('Kuota gratis: ${state.freeQuotaRemaining} hari • Kredit: ${state.creditBalance}'),
        subtitle: Text(state.dayActive ? 'Hari Pemantauan AI hari ini: AKTIF' : 'Hari Pemantauan AI hari ini: belum aktif'),
        trailing: IconButton(
          tooltip: 'Tambah 1 kredit (demo)',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onAddDemoCredit,
        ),
      ),
    );
  }
}
