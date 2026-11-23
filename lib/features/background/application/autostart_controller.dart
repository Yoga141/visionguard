import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/settings_repository.dart';
import '../data/autostart_service.dart';

@immutable
class AutostartState {
  const AutostartState({this.supported = false, this.enabled = false, this.busy = false, this.error});
  final bool supported;
  final bool enabled;
  final bool busy;
  final String? error;
}

/// Kunci tabel `settings` untuk pilihan autostart (PGT-02). Sumber kebenaran
/// tetap registri OS; nilai ini hanya cermin agar pilihan tercatat lokal.
const autostartSettingKey = 'autostart';

final autostartControllerProvider =
    NotifierProvider<AutostartController, AutostartState>(AutostartController.new);

/// Toggle "Jalankan saat komputer menyala" di Pengaturan (PGT-02, S-10).
class AutostartController extends Notifier<AutostartState> {
  AutostartService get _service => ref.read(autostartServiceProvider);

  @override
  AutostartState build() => AutostartState(supported: ref.read(autostartServiceProvider).isSupported);

  Future<void> load() async {
    if (!_service.isSupported) return;
    try {
      state = AutostartState(supported: true, enabled: await _service.isEnabled());
    } catch (e) {
      state = const AutostartState(supported: true, error: 'Status autostart tidak dapat dibaca.');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_service.isSupported || state.busy) return;
    state = AutostartState(supported: true, enabled: state.enabled, busy: true);
    try {
      await _service.setEnabled(enabled);
      state = AutostartState(supported: true, enabled: enabled);
      try {
        await ref.read(settingsRepositoryProvider).set(autostartSettingKey, '$enabled');
      } catch (e) {
        debugPrint('Gagal menyimpan pengaturan autostart: $e');
      }
    } catch (e) {
      state = AutostartState(
          supported: true, enabled: !enabled, error: 'Gagal mengubah autostart. Coba lagi.');
    }
  }
}
