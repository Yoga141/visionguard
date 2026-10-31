import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/cv_constants.dart';
import '../data/settings_repository.dart';

/// Sensitivitas deteksi kedipan → faktor τ (DOCS_SPEC §16 #5).
enum Sensitivity { rendah, sedang, tinggi }

extension SensitivityX on Sensitivity {
  String get label => switch (this) {
        Sensitivity.rendah => 'Rendah',
        Sensitivity.sedang => 'Sedang',
        Sensitivity.tinggi => 'Tinggi',
      };

  double get tauFactor => switch (this) {
        Sensitivity.rendah => CvConstants.tauFactorLow,
        Sensitivity.sedang => CvConstants.tauFactor,
        Sensitivity.tinggi => CvConstants.tauFactorHigh,
      };
}

/// D10 Pengaturan (PGT-01, UC-21).
@immutable
class AppSettings {
  final Sensitivity sensitivity;
  final bool popupEnabled;
  final bool notificationEnabled;
  final bool soundEnabled;
  final int interval202020Min;

  const AppSettings({
    this.sensitivity = Sensitivity.sedang,
    this.popupEnabled = true,
    this.notificationEnabled = true,
    this.soundEnabled = true,
    this.interval202020Min = CvConstants.rule202020DefaultMin,
  });

  static const defaults = AppSettings();

  AppSettings copyWith({
    Sensitivity? sensitivity,
    bool? popupEnabled,
    bool? notificationEnabled,
    bool? soundEnabled,
    int? interval202020Min,
  }) =>
      AppSettings(
        sensitivity: sensitivity ?? this.sensitivity,
        popupEnabled: popupEnabled ?? this.popupEnabled,
        notificationEnabled: notificationEnabled ?? this.notificationEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        interval202020Min: interval202020Min ?? this.interval202020Min,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.sensitivity == sensitivity &&
      other.popupEnabled == popupEnabled &&
      other.notificationEnabled == notificationEnabled &&
      other.soundEnabled == soundEnabled &&
      other.interval202020Min == interval202020Min;

  @override
  int get hashCode =>
      Object.hash(sensitivity, popupEnabled, notificationEnabled, soundEnabled, interval202020Min);
}

/// Kunci di tabel `settings`.
class SettingKeys {
  SettingKeys._();

  static const sensitivity = 'sensitivity';
  static const popup = 'reminder_popup';
  static const notification = 'reminder_notification';
  static const sound = 'reminder_sound';
  static const interval202020 = 'interval_202020_min';

  static const all = [sensitivity, popup, notification, sound, interval202020];
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Memuat & menyimpan pengaturan. Perubahan langsung terlihat oleh provider
/// lain (τ ke BlinkAnalyzer, interval ke timer) tanpa restart.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.defaults;

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  /// Dipanggil saat aplikasi dibuka. Nilai rusak/tidak dikenal → bawaan.
  Future<void> load() async {
    try {
      final m = await _repo.all();
      bool flag(String key, bool def) => m[key] == null ? def : m[key] == 'true';
      final interval = int.tryParse(m[SettingKeys.interval202020] ?? '');
      state = AppSettings(
        sensitivity: Sensitivity.values.asNameMap()[m[SettingKeys.sensitivity]] ??
            AppSettings.defaults.sensitivity,
        popupEnabled: flag(SettingKeys.popup, AppSettings.defaults.popupEnabled),
        notificationEnabled:
            flag(SettingKeys.notification, AppSettings.defaults.notificationEnabled),
        soundEnabled: flag(SettingKeys.sound, AppSettings.defaults.soundEnabled),
        interval202020Min: interval != null && validateInterval(interval) == null
            ? interval
            : AppSettings.defaults.interval202020Min,
      );
    } catch (e) {
      debugPrint('Gagal memuat pengaturan: $e');
    }
  }

  /// Null jika valid, selain itu pesan kesalahan.
  static String? validateInterval(int? minutes) {
    if (minutes == null) return 'Masukkan angka.';
    if (minutes < CvConstants.rule202020MinMin || minutes > CvConstants.rule202020MaxMin) {
      return 'Interval harus ${CvConstants.rule202020MinMin}–${CvConstants.rule202020MaxMin} menit.';
    }
    return null;
  }

  Future<void> setSensitivity(Sensitivity v) {
    state = state.copyWith(sensitivity: v);
    return _save(SettingKeys.sensitivity, v.name);
  }

  Future<void> setPopup(bool v) {
    state = state.copyWith(popupEnabled: v);
    return _save(SettingKeys.popup, '$v');
  }

  Future<void> setNotification(bool v) {
    state = state.copyWith(notificationEnabled: v);
    return _save(SettingKeys.notification, '$v');
  }

  Future<void> setSound(bool v) {
    state = state.copyWith(soundEnabled: v);
    return _save(SettingKeys.sound, '$v');
  }

  /// Mengembalikan pesan kesalahan jika di luar 10–60 menit (tidak disimpan).
  Future<String?> setInterval202020(int minutes) async {
    final error = validateInterval(minutes);
    if (error != null) return error;
    state = state.copyWith(interval202020Min: minutes);
    await _save(SettingKeys.interval202020, '$minutes');
    return null;
  }

  Future<void> resetToDefaults() async {
    state = AppSettings.defaults;
    try {
      for (final k in SettingKeys.all) {
        await _repo.remove(k);
      }
    } catch (e) {
      debugPrint('Gagal mereset pengaturan: $e');
    }
  }

  Future<void> _save(String key, String value) async {
    try {
      await _repo.set(key, value);
    } catch (e) {
      debugPrint('Gagal menyimpan pengaturan: $e');
    }
  }
}
