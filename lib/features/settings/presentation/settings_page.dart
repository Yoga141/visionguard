import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/cv_constants.dart';
import '../../auth/application/auth_controller.dart';
import '../../monitoring/application/monitoring_controller.dart';
import '../application/settings_controller.dart';
import '../../../shared/widgets/help_button.dart';
import '../../help/domain/help_content.dart';
import '../../background/application/autostart_controller.dart';

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

  /// UC-05: peringatan → kata sandi → `DELETE /me` → hapus data lokal → Login.
  Future<void> _deleteAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;

    await ref.read(monitoringControllerProvider.notifier).stop();
    final result = await ref.read(authControllerProvider.notifier).deleteAccount(password);
    if (!mounted) return;
    _snack(result.message);
    if (result.ok) context.go(Routes.login);
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
      appBar: AppBar(
        title: const Text('Pengaturan'),
        actions: const [HelpButton(topic: HelpTopic.pengaturan)],
      ),
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
                const _AutostartTile(),
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

/// Dialog hapus akun (UC-05): peringatan data & sisa kredit hilang, lalu
/// kata sandi untuk verifikasi. Mengembalikan kata sandi, atau null bila batal.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _understood = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit => _understood && _password.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: const Text('Hapus akun?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akun, perangkat, dan statistik di server dihapus permanen, termasuk sisa kredit. '
              'Riwayat transaksi disimpan tanpa identitas Anda. '
              'Data di perangkat ini (kalibrasi, metrik, pengaturan) juga dihapus.',
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: const Text('Saya mengerti dan ingin menghapus akun'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: _canSubmit ? () => Navigator.pop(context, _password.text) : null,
          child: const Text('Hapus Akun'),
        ),
      ],
    );
  }
}

/// PGT-02: jalankan saat komputer menyala (Windows; aplikasi terbuka di tray).
class _AutostartTile extends ConsumerStatefulWidget {
  const _AutostartTile();

  @override
  ConsumerState<_AutostartTile> createState() => _AutostartTileState();
}

class _AutostartTileState extends ConsumerState<_AutostartTile> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(autostartControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(autostartControllerProvider);
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.power_settings_new),
        title: const Text('Jalankan saat komputer menyala'),
        subtitle: Text(!a.supported
            ? 'Hanya tersedia di aplikasi desktop Windows.'
            : a.error ?? 'VisionGuard terbuka di system tray setelah masuk Windows.'),
        value: a.enabled,
        onChanged: !a.supported || a.busy
            ? null
            : (v) => ref.read(autostartControllerProvider.notifier).setEnabled(v),
      ),
    );
  }
}
