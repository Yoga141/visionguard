import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Autostart saat OS menyala (PGT-02, desktop).
abstract class AutostartService {
  bool get isSupported;
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);
}

/// Argumen yang ditambahkan ke perintah autostart; aplikasi lalu langsung
/// bersembunyi ke tray.
const autostartArg = '--autostart';

class UnsupportedAutostart implements AutostartService {
  const UnsupportedAutostart();
  @override
  bool get isSupported => false;
  @override
  Future<bool> isEnabled() async => false;
  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// Windows: nilai `VisionGuard` di `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
/// (per pengguna, tanpa hak admin), lewat `reg.exe` bawaan Windows.
class WindowsAutostart implements AutostartService {
  WindowsAutostart({String? executable, this.runner = Process.run})
      : executable = executable ?? Platform.resolvedExecutable;

  static const runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const valueName = 'VisionGuard';

  final String executable;
  final Future<ProcessResult> Function(String, List<String>) runner;

  /// Data registri: path exe dalam tanda kutip + [autostartArg].
  String get command => '"$executable" $autostartArg';

  @override
  bool get isSupported => true;

  @override
  Future<bool> isEnabled() async {
    final r = await runner('reg', ['query', runKey, '/v', valueName]);
    return r.exitCode == 0 && '${r.stdout}'.contains(executable);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final r = enabled
        ? await runner('reg', ['add', runKey, '/v', valueName, '/t', 'REG_SZ', '/d', command, '/f'])
        : await runner('reg', ['delete', runKey, '/v', valueName, '/f']);
    // Menghapus nilai yang tidak ada → exit 1; anggap sudah nonaktif.
    if (r.exitCode != 0 && enabled) {
      throw ProcessException('reg', const [], '${r.stderr}'.trim(), r.exitCode);
    }
  }
}

final autostartServiceProvider = Provider<AutostartService>((ref) {
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows &&
      !Platform.environment.containsKey('FLUTTER_TEST')) {
    return WindowsAutostart();
  }
  return const UnsupportedAutostart();
});
