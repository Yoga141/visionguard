import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/cv_engine/cv_providers.dart';
import 'package:visionguard/features/auth/application/auth_controller.dart';
import 'package:visionguard/features/background/application/app_visibility.dart';
import 'package:visionguard/features/background/application/autostart_controller.dart';
import 'package:visionguard/features/background/application/background_coordinator.dart';
import 'package:visionguard/features/background/application/tray_actions.dart';
import 'package:visionguard/features/background/application/tray_menu.dart';
import 'package:visionguard/features/background/data/autostart_service.dart';
import 'package:visionguard/features/background/data/foreground_service.dart';
import 'package:visionguard/features/background/data/screen_state.dart';
import 'package:visionguard/features/calibration/application/calibration_controller.dart';
import 'package:visionguard/features/calibration/data/calibration_repository.dart';
import 'package:visionguard/features/credits/data/credit_repository.dart';
import 'package:visionguard/features/credits/domain/credit_models.dart';
import 'package:visionguard/features/monitoring/application/monitoring_controller.dart';
import 'package:visionguard/features/reminders/application/reminder_controller.dart';
import 'package:visionguard/features/reminders/data/notification_service.dart';
import 'package:visionguard/features/reminders/domain/reminder.dart';
import 'package:visionguard/features/settings/application/settings_controller.dart';

import 'database_test.dart' show memoryDb;

/// Kamera tiruan: [blocked] = kamera dipakai aplikasi lain (PMT-08).
class FakeCameraSource extends CameraSource {
  bool blocked = false;
  int starts = 0;
  bool _on = false;
  CameraFailure _failure = CameraFailure.none;

  @override
  Future<void> start() async {
    starts++;
    _failure = blocked ? CameraFailure.unavailable : CameraFailure.none;
    _on = !blocked;
  }

  @override
  Future<void> stop() async => _on = false;

  @override
  CameraFailure get failure => _failure;

  @override
  bool get usingRealCamera => _on;

  @override
  bool get streamingRealFrames => _on;

  @override
  String get cameraId => 'fake-cam';
}

/// Menghitung panggilan aktivasi hari (§8.2) agar terlihat kredit tidak dipotong ulang.
class CountingCreditRepository extends FakeCreditRepository {
  int activations = 0;
  @override
  Future<ActivationResult> activateToday() {
    activations++;
    return super.activateToday();
  }
}

class FakeForegroundService implements ForegroundServiceGateway {
  final calls = <String>[];
  @override
  Future<void> start({required String title, required String text}) async => calls.add('start');
  @override
  Future<void> update({required String text}) async => calls.add('update');
  @override
  Future<void> stop() async => calls.add('stop');
}

class FakeAutostart implements AutostartService {
  bool enabled = false;
  bool fail = false;
  @override
  bool get isSupported => true;
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<void> setEnabled(bool v) async {
    if (fail) throw const ProcessException('reg', [], 'akses ditolak', 1);
    enabled = v;
  }
}

class RecordingNotifier implements SystemNotifier {
  int shown = 0;
  @override
  Stream<String> get actions => const Stream.empty();
  @override
  Future<bool> show({required String title, required String body, required bool sound}) async {
    shown++;
    return true;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // --------------------------------------------------------------- Menu tray
  group('Menu system tray (S-11)', () {
    List<String> labels(List<TrayEntry> e) => [for (final x in e) if (!x.separator) x.label];

    test('isi menu: status, Jeda/Lanjut, Mode Fokus, Buka Dashboard, Logout, Keluar', () {
      final menu = buildTrayMenu(
          monitoring: const MonitoringState(), reminders: const ReminderState(), loggedIn: true);
      expect(labels(menu), [
        'Pemantauan tidak berjalan',
        'Jeda pemantauan',
        'Mode Fokus',
        'Buka Dashboard',
        'Logout',
        'Keluar',
      ]);
      // Idle: status hanya label, jeda & fokus nonaktif.
      expect(menu.first.enabled, isFalse);
      expect(menu.firstWhere((e) => e.action == TrayAction.pauseResume).enabled, isFalse);
      final focus = menu.firstWhere((e) => e.label == 'Mode Fokus');
      expect(focus.enabled, isFalse);
      expect(focus.children.map((c) => c.focusMinutes), [30, 60, 90, 120]);
    });

    test('berjalan / dijeda / Mode Fokus / logout tercermin di menu', () {
      final running = buildTrayMenu(
          monitoring: const MonitoringState(mode: MonitoringMode.ai, fatigueScore: 42),
          reminders: const ReminderState(),
          loggedIn: true);
      expect(running.first.label, 'Pemantauan AI berjalan • skor 42');
      expect(running.firstWhere((e) => e.action == TrayAction.pauseResume).enabled, isTrue);

      final paused = buildTrayMenu(
          monitoring: const MonitoringState(mode: MonitoringMode.ai, paused: true),
          reminders: ReminderState(focusUntil: DateTime(2026, 11, 23, 14, 5)),
          loggedIn: false);
      expect(paused.first.label, 'Pemantauan AI dijeda • Fokus hingga 14.05');
      expect(paused.firstWhere((e) => e.action == TrayAction.pauseResume).label,
          'Lanjutkan pemantauan');
      final focus = paused.firstWhere((e) => e.label == 'Mode Fokus');
      expect(focus.children.last.action, TrayAction.endFocus);
      expect(paused.firstWhere((e) => e.action == TrayAction.logout).enabled, isFalse);
    });

    test('status Mode Timer menunggu kamera', () {
      expect(
          trayStatus(const MonitoringState(mode: MonitoringMode.timer, waitingForCamera: true),
              const ReminderState()),
          'Mode Timer • menunggu kamera');
    });
  });

  // ---------------------------------------------- Controller dengan database
  group('Pemantauan latar belakang', () {
    late AppDatabase db;
    late ProviderContainer container;
    late FakeCameraSource camera;
    late CountingCreditRepository credits;
    late FakeForegroundService service;
    late StreamController<ScreenEvent> screen;

    setUp(() async {
      db = memoryDb();
      camera = FakeCameraSource();
      credits = CountingCreditRepository();
      service = FakeForegroundService();
      screen = StreamController<ScreenEvent>.broadcast();
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        cameraSourceProvider.overrideWithValue(camera),
        creditRepositoryProvider.overrideWithValue(credits),
        foregroundServiceProvider.overrideWithValue(service),
        screenEventsProvider.overrideWithValue(screen.stream),
      ]);
      await container.read(calibrationRepositoryProvider).save(
          cameraId: 'fake-cam', earBaseline: 0.3, focalPx: 600);
      await container.read(calibrationControllerProvider.notifier).restoreSaved(cameraId: 'fake-cam');
    });
    tearDown(() async {
      await container.read(monitoringControllerProvider.notifier).stop();
      container.dispose();
      await screen.close();
      await db.close();
    });

    MonitoringController ctrl() => container.read(monitoringControllerProvider.notifier);
    MonitoringState st() => container.read(monitoringControllerProvider);

    test('kamera dipakai app lain → Mode Timer, coba lagi → kembali ke AI tanpa aktivasi ulang',
        () async {
      camera.blocked = true;
      expect(await ctrl().startAi(), StartAiOutcome.cameraUnavailable);
      expect(st().mode, MonitoringMode.timer);
      expect(st().waitingForCamera, isTrue);
      expect(st().message, contains('dipakai aplikasi lain'));
      expect(credits.activations, 1);

      // Masih dipakai → tetap Mode Timer.
      expect(await ctrl().retryCameraNow(), isFalse);
      expect(st().mode, MonitoringMode.timer);

      camera.blocked = false;
      expect(await ctrl().retryCameraNow(), isTrue);
      expect(st().mode, MonitoringMode.ai);
      expect(st().waitingForCamera, isFalse);
      expect(st().cameraActive, isTrue);
      expect(credits.activations, 1, reason: 'kredit tidak dipotong lagi');

      final modes = (await db.select(db.sessions).get()).map((s) => s.mode);
      expect(modes, [SessionMode.timer, SessionMode.ai]);
    });

    test('Mode Timer pilihan pengguna tidak memicu coba ulang kamera', () async {
      ctrl().useTimerMode();
      final before = camera.starts;
      expect(await ctrl().retryCameraNow(), isFalse);
      expect(camera.starts, before);
    });

    test('Jeda menutup sesi & mematikan kamera; Lanjut membuka sesi baru', () async {
      await ctrl().startAi();
      await ctrl().pause();
      expect(st().paused, isTrue);
      expect(st().mode, MonitoringMode.ai);
      expect(camera.usingRealCamera, isFalse);
      var sessions = await db.select(db.sessions).get();
      expect(sessions.single.endedAt, isNotNull);

      await ctrl().resume();
      expect(st().paused, isFalse);
      expect(camera.usingRealCamera, isTrue);
      sessions = await db.select(db.sessions).get();
      expect(sessions.length, 2);
      expect(sessions.last.endedAt, isNull);
      expect(credits.activations, 1);
    });

    test('TrayActions: Jeda/Lanjut, Mode Fokus, Logout', () async {
      final actions = TrayActions(<T>(p) => container.read(p));
      ctrl().useTimerMode();
      await actions.run(TrayAction.pauseResume);
      expect(st().paused, isTrue);
      await actions.run(TrayAction.pauseResume);
      expect(st().paused, isFalse);

      await actions.run(TrayAction.startFocus, focusMinutes: 30);
      expect(container.read(reminderControllerProvider).focusActive, isTrue);
      await actions.run(TrayAction.endFocus);
      expect(container.read(reminderControllerProvider).focusActive, isFalse);

      await actions.run(TrayAction.logout);
      expect(st().mode, MonitoringMode.idle);
      expect(container.read(authControllerProvider).isLoggedIn, isFalse);
      expect(await actions.run(TrayAction.openDashboard), isFalse);
    });

    test('foreground service ikut Mode AI; layar mati → pemantauan berhenti (KDL-02)', () async {
      container.read(backgroundCoordinatorProvider);
      await ctrl().startAi();
      expect(service.calls, ['start']);
      await ctrl().pause();
      expect(service.calls.last, 'stop');
      await ctrl().resume();
      expect(service.calls.where((c) => c == 'start').length, 2);

      screen.add(ScreenEvent.off);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(st().mode, MonitoringMode.idle);
      expect(st().message, contains('layar mati'));
      expect(service.calls.last, 'stop');
      expect((await db.select(db.sessions).get()).every((s) => s.endedAt != null), isTrue);
    });

    test('Mode Timer tidak menyalakan foreground service', () async {
      container.read(backgroundCoordinatorProvider);
      ctrl().useTimerMode();
      await Future<void>.delayed(Duration.zero);
      expect(service.calls, isEmpty);
    });
  });

  // ------------------------------------------ Pengingat saat jendela di tray
  test('jendela di tray → pengingat lewat notifikasi sistem meski notifikasi dimatikan', () async {
    final db = memoryDb();
    final notifier = RecordingNotifier();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      systemNotifierProvider.overrideWithValue(notifier),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await container.read(settingsControllerProvider.notifier).setNotification(false);
    final reminders = container.read(reminderControllerProvider.notifier);

    expect(reminders.show(ReminderType.blink), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.shown, 0); // jendela terlihat: pop-up saja
    reminders.closeActive();

    container.read(appInBackgroundProvider.notifier).state = true;
    expect(reminders.show(ReminderType.distance), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.shown, 1);
    reminders.closeActive();
  });

  // ---------------------------------------------------------------- Kamera
  test('klasifikasi kegagalan kamera (PMT-08)', () {
    expect(CameraSource.classifyFailure(StateError('x'), camerasListed: false), CameraFailure.noCamera);
    expect(CameraSource.classifyFailure(CameraException('CameraAccessDenied', 'izin'), camerasListed: true),
        CameraFailure.permissionDenied);
    expect(CameraSource.classifyFailure(CameraException('camera_error', 'in use'), camerasListed: true),
        CameraFailure.unavailable);
  });

  // ------------------------------------------------------------- Autostart
  group('Autostart (PGT-02)', () {
    test('WindowsAutostart menulis & menghapus nilai Run di HKCU', () async {
      final calls = <List<String>>[];
      var queryOut = '';
      final a = WindowsAutostart(
        executable: r'C:\Apps\VisionGuard\visionguard.exe',
        runner: (cmd, args) async {
          calls.add([cmd, ...args]);
          final exit = args.first == 'query' && queryOut.isEmpty ? 1 : 0;
          return ProcessResult(0, exit, queryOut, '');
        },
      );
      expect(a.command, r'"C:\Apps\VisionGuard\visionguard.exe" --autostart');
      expect(await a.isEnabled(), isFalse);

      await a.setEnabled(true);
      expect(calls.last, [
        'reg', 'add', WindowsAutostart.runKey, '/v', 'VisionGuard', '/t', 'REG_SZ', '/d', a.command, '/f',
      ]);
      queryOut = '    VisionGuard    REG_SZ    ${a.command}';
      expect(await a.isEnabled(), isTrue);

      await a.setEnabled(false);
      expect(calls.last, ['reg', 'delete', WindowsAutostart.runKey, '/v', 'VisionGuard', '/f']);
    });

    test('AutostartController memuat, mengubah, dan menangani kegagalan', () async {
      final db = memoryDb();
      final svc = FakeAutostart();
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        autostartServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final ctrl = container.read(autostartControllerProvider.notifier);
      await ctrl.load();
      expect(container.read(autostartControllerProvider).enabled, isFalse);

      await ctrl.setEnabled(true);
      expect(svc.enabled, isTrue);
      expect(container.read(autostartControllerProvider).enabled, isTrue);
      final row = await (db.select(db.settings)..where((s) => s.key.equals(autostartSettingKey)))
          .getSingle();
      expect(row.value, 'true');

      svc.fail = true;
      await ctrl.setEnabled(false);
      final s = container.read(autostartControllerProvider);
      expect(s.enabled, isTrue);
      expect(s.error, isNotNull);
    });

    test('platform tanpa autostart → toggle nonaktif', () {
      expect(const UnsupportedAutostart().isSupported, isFalse);
    });
  });
}
