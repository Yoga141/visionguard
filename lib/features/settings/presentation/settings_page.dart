import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/cv_constants.dart';
import '../../auth/application/auth_controller.dart';
import '../../monitoring/application/monitoring_controller.dart';
import '../application/settings_controller.dart';

/// S-10 Pengaturan (PGT-01, PGT-02, UC-21, AKN-02, AKN-04).
/// Setiap perubahan langsung disimpan ke tabel `settings` dan diterapkan.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _interval;
  final _intervalKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _interval = TextEditingController(
        text: '${ref.read(settingsControllerProvider).interval202020Min}');
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  SettingsController get _ctrl => ref.read(settingsControllerProvider.notifier);

  void _snack(String text) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveInterval() async {
    if (!_intervalKey.currentState!.validate()) return;
    final error = await _ctrl.setInterval202020(int.parse(_interval.text));
    if (!mounted) return;
    _snack(error ?? 'Interval 20-20-20 disimpan: ${_interval.text} menit.');
  }

  Future<void> _resetDefaults() async {
    await _ctrl.resetToDefaults();
    if (!mounted) return;
    _snack('Pengaturan dikembalikan ke bawaan.');
  }

  Future<void> _logout() async {
    await ref.read(monitoringControllerProvider.notifier).stop();
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go(Routes.login);
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Hapus akun?'),
        content: const Text(
          'Akun, perangkat, dan statistik akan dihapus permanen, termasuk sisa kredit. '
          'Data lokal (kalibrasi, metrik, pengaturan) juga dihapus.\n\n'
          'Catatan: penghapusan permanen baru aktif setelah backend tersedia.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _snack('Belum tersedia: penghapusan akun permanen aktif setelah backend tersedia.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    // Sinkronkan kolom interval bila nilai berubah dari luar (mis. reset).
    ref.listen(settingsControllerProvider.select((v) => v.interval202020Min), (_, next) {
      if (_interval.text != '$next') _interval.text = '$next';
    });

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                section('Deteksi'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sensitivitas deteksi kedipan'),
                        const SizedBox(height: 8),
                        SegmentedButton<Sensitivity>(
                          segments: [
                            for (final v in Sensitivity.values)
                              ButtonSegment(value: v, label: Text(v.label)),
                          ],
                          selected: {s.sensitivity},
                          onSelectionChanged: (v) => _ctrl.setSensitivity(v.first),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ambang mata tertutup τ = '
                          '${s.sensitivity.tauFactor.toStringAsFixed(2).replaceAll('.', ',')} × baseline EAR.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                section('Pengingat'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.web_asset),
                        title: const Text('Pop-up'),
                        value: s.popupEnabled,
                        onChanged: _ctrl.setPopup,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifikasi'),
                        value: s.notificationEnabled,
                        onChanged: _ctrl.setNotification,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up_outlined),
                        title: const Text('Suara'),
                        value: s.soundEnabled,
                        onChanged: _ctrl.setSound,
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _intervalKey,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const Key('interval202020'),
                                  controller: _interval,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    labelText: 'Interval 20-20-20 (menit)',
                                    helperText:
                                        '${CvConstants.rule202020MinMin}–${CvConstants.rule202020MaxMin} menit, '
                                        'bawaan ${CvConstants.rule202020DefaultMin}',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      SettingsController.validateInterval(int.tryParse(v ?? '')),
                                  onFieldSubmitted: (_) => _saveInterval(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: FilledButton.tonal(
                                    // Tema memakai tombol lebar penuh; di dalam Row perlu lebar minimum.
                                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                                    onPressed: _saveInterval,
                                    child: const Text('Simpan')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                section('Sistem'),
                const Card(
                  child: SwitchListTile(
                    secondary: Icon(Icons.power_settings_new),
                    title: Text('Jalankan saat komputer menyala'),
                    subtitle: Text('Segera hadir'),
                    value: false,
                    onChanged: null, // PGT-02 belum diimplementasikan
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _resetDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('Kembalikan ke bawaan'),
                ),
                section('Akun'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(auth.userName ?? 'Pengguna'),
                        subtitle: Text(auth.email ?? '-'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Logout'),
                        onTap: _logout,
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                        title: Text('Hapus Akun', style: TextStyle(color: theme.colorScheme.error)),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
