import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../auth/application/auth_controller.dart';
import '../../monitoring/application/monitoring_controller.dart';

/// S-02 Onboarding Privasi (UC-06, KLB-01, KSL-01).
class PrivacyOnboardingPage extends ConsumerStatefulWidget {
  const PrivacyOnboardingPage({super.key});

  @override
  ConsumerState<PrivacyOnboardingPage> createState() => _PrivacyOnboardingPageState();
}

class _PrivacyOnboardingPageState extends ConsumerState<PrivacyOnboardingPage> {
  bool _agreePrivacy = false;
  bool _agreeMedical = false;

  void _accept() {
    ref.read(authControllerProvider.notifier).acceptPrivacy();
    // Izin kamera diminta oleh sistem operasi saat kamera pertama kali
    // dinyalakan di halaman Kalibrasi.
    context.go(Routes.calibration);
  }

  void _decline() {
    // UC-06 alur alternatif: tanpa persetujuan → Mode Timer tanpa kamera.
    ref.read(monitoringControllerProvider.notifier).useTimerMode();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Berjalan dalam Mode Timer (tanpa kamera).')),
    );
    context.go(Routes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privasi & Izin Kamera')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.shield_outlined, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Kameramu, datamu.',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const _InfoTile(
                  icon: Icons.memory,
                  title: 'Diproses di perangkat',
                  body: 'Gambar kamera hanya dianalisis di memori perangkat ini, '
                      'lalu langsung dibuang.',
                ),
                const _InfoTile(
                  icon: Icons.cloud_off_outlined,
                  title: 'Tidak pernah dikirim',
                  body: 'Tidak ada foto atau video wajah yang disimpan atau dikirim ke server. '
                      'Server hanya menerima ringkasan berupa angka.',
                ),
                const _InfoTile(
                  icon: Icons.videocam_outlined,
                  title: 'Selalu terlihat',
                  body: 'Indikator "Kamera aktif" selalu tampil selama kamera menyala.',
                ),
                const _InfoTile(
                  icon: Icons.medical_information_outlined,
                  title: 'Bukan alat medis',
                  body: 'VisionGuard hanya memberi estimasi dan pengingat, bukan diagnosis. '
                      'Periksakan keluhan mata ke dokter mata.',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _agreePrivacy,
                  onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
                  title: const Text('Saya memahami cara VisionGuard memproses kamera'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _agreeMedical,
                  onChanged: (v) => setState(() => _agreeMedical = v ?? false),
                  title: const Text('Saya memahami VisionGuard bukan alat medis'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _agreePrivacy && _agreeMedical ? _accept : null,
                  child: const Text('Setuju & Lanjut ke Kalibrasi'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _decline,
                  child: const Text('Tidak sekarang, pakai Mode Timer saja'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
