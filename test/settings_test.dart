import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/app/theme.dart';
import 'package:visionguard/core/constants/cv_constants.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/features/calibration/application/calibration_controller.dart';
import 'package:visionguard/features/calibration/data/calibration_repository.dart';
import 'package:visionguard/features/monitoring/application/monitoring_controller.dart';
import 'package:visionguard/features/settings/application/settings_controller.dart';
import 'package:visionguard/features/settings/data/settings_repository.dart';
import 'package:visionguard/features/settings/presentation/settings_page.dart';

import 'database_test.dart' show memoryDb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  ProviderContainer newContainer() =>
      ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test('pemetaan sensitivitas → τ: 0,65 / 0,70 / 0,75 (§16 #5)', () {
    expect(Sensitivity.rendah.tauFactor, 0.65);
    expect(Sensitivity.sedang.tauFactor, 0.70);
    expect(Sensitivity.tinggi.tauFactor, 0.75);
    expect(AppSettings.defaults.sensitivity, Sensitivity.sedang);
    expect(AppSettings.defaults.interval202020Min, 20);
  });

  group('SettingsController', () {
    test('perubahan disimpan dan dimuat kembali saat aplikasi dibuka', () async {
      final c1 = newContainer();
      final ctrl = c1.read(settingsControllerProvider.notifier);
      await ctrl.setSensitivity(Sensitivity.tinggi);
      await ctrl.setPopup(false);
      await ctrl.setSound(false);
      expect(await ctrl.setInterval202020(30), isNull);
      c1.dispose();

      final c2 = newContainer();
      await c2.read(settingsControllerProvider.notifier).load();
      expect(
        c2.read(settingsControllerProvider),
        const AppSettings(
          sensitivity: Sensitivity.tinggi,
          popupEnabled: false,
          notificationEnabled: true,
          soundEnabled: false,
          interval202020Min: 30,
        ),
      );
      c2.dispose();
    });

    test('interval di luar 10–60 menit ditolak dan tidak disimpan', () async {
      final c = newContainer();
      final ctrl = c.read(settingsControllerProvider.notifier);
      expect(await ctrl.setInterval202020(9), contains('10–60'));
      expect(await ctrl.setInterval202020(61), contains('10–60'));
      expect(await ctrl.setInterval202020(10), isNull);
      expect(await ctrl.setInterval202020(60), isNull);
      expect(c.read(settingsControllerProvider).interval202020Min, 60);
      expect(SettingsController.validateInterval(null), isNotNull);
      c.dispose();
    });

    test('nilai tersimpan yang rusak → bawaan', () async {
      final repo = SettingsRepository(db);
      await repo.set(SettingKeys.sensitivity, 'ekstrem');
      await repo.set(SettingKeys.interval202020, '999');
      final c = newContainer();
      await c.read(settingsControllerProvider.notifier).load();
      expect(c.read(settingsControllerProvider), AppSettings.defaults);
      c.dispose();
    });

    test('Kembalikan ke bawaan menghapus nilai tersimpan', () async {
      final c = newContainer();
      final ctrl = c.read(settingsControllerProvider.notifier);
      await ctrl.setSensitivity(Sensitivity.rendah);
      await ctrl.setNotification(false);
      await ctrl.resetToDefaults();
      expect(c.read(settingsControllerProvider), AppSettings.defaults);
      expect(await SettingsRepository(db).all(), isEmpty);
      c.dispose();
    });
  });

  group('Diterapkan langsung tanpa restart (UC-21)', () {
    test('sensitivitas mengubah τ BlinkAnalyzer yang sedang berjalan', () async {
      final c = newContainer();
      await c.read(calibrationRepositoryProvider).save(
          cameraId: CameraSource.simulatedCameraId, earBaseline: 0.3, focalPx: 600);
      await c.read(calibrationControllerProvider.notifier).restoreSaved();
      await c.read(settingsControllerProvider.notifier).setSensitivity(Sensitivity.rendah);

      final m = c.read(monitoringControllerProvider.notifier);
      await m.startAi();
      expect(m.activeTauFactor, 0.65);
      await c.read(settingsControllerProvider.notifier).setSensitivity(Sensitivity.tinggi);
      expect(m.activeTauFactor, 0.75);
      await m.stop();
      c.dispose();
    });

    test('interval 20-20-20 dipakai Mode Timer dan berlaku saat berjalan', () async {
      final c = newContainer();
      await c.read(settingsControllerProvider.notifier).setInterval202020(25);
      final m = c.read(monitoringControllerProvider.notifier);
      m.useTimerMode();
      expect(c.read(monitoringControllerProvider).secondsToNext202020, 25 * 60);
      await c.read(settingsControllerProvider.notifier).setInterval202020(15);
      expect(c.read(monitoringControllerProvider).secondsToNext202020, 15 * 60);
      await m.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.dispose();
    });
  });

  group('SettingsPage', () {
    Future<ProviderContainer> pumpPage(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      final c = newContainer();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: AppTheme.light, home: const SettingsPage()),
      ));
      return c;
    }

    testWidgets('menampilkan semua opsi S-10', (tester) async {
      final c = await pumpPage(tester);
      for (final t in [
        'Rendah', 'Sedang', 'Tinggi', 'Pop-up', 'Notifikasi', 'Suara', //
        'Kembalikan ke bawaan', 'Logout', 'Hapus Akun', 'Segera hadir',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // Autostart tampil tetapi nonaktif.
      final autostart = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Jalankan saat komputer menyala'));
      expect(autostart.onChanged, isNull);

      await tester.tap(find.text('Tinggi'));
      await tester.pump();
      expect(c.read(settingsControllerProvider).sensitivity, Sensitivity.tinggi);
      expect(find.textContaining('τ = 0,75'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('validasi interval 10–60 menit', (tester) async {
      final c = await pumpPage(tester);
      await tester.enterText(find.byKey(const Key('interval202020')), '5');
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      expect(
          find.text('Interval harus ${CvConstants.rule202020MinMin}–'
              '${CvConstants.rule202020MaxMin} menit.'),
          findsOneWidget);
      expect(c.read(settingsControllerProvider).interval202020Min, 20);

      await tester.enterText(find.byKey(const Key('interval202020')), '45');
      await tester.tap(find.text('Simpan'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(c.read(settingsControllerProvider).interval202020Min, 45);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('Hapus Akun meminta konfirmasi dan memberi catatan backend', (tester) async {
      final c = await pumpPage(tester);
      await tester.tap(find.text('Hapus Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus akun?'), findsOneWidget);
      expect(find.textContaining('setelah backend tersedia'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus akun?'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });
}
