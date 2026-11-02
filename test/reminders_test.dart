import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/app/theme.dart';
import 'package:visionguard/core/constants/cv_constants.dart';
import 'package:visionguard/core/database/app_database.dart';
import 'package:visionguard/core/database/database_providers.dart';
import 'package:visionguard/cv_engine/camera_source.dart';
import 'package:visionguard/cv_engine/distance_estimator.dart';
import 'package:visionguard/cv_engine/dummy_face_analyzer.dart';
import 'package:visionguard/features/monitoring/application/monitoring_controller.dart';
import 'package:visionguard/features/monitoring/data/alert_repository.dart';
import 'package:visionguard/features/monitoring/data/session_repository.dart';
import 'package:visionguard/features/reminders/application/break_verifier.dart';
import 'package:visionguard/features/reminders/application/reminder_controller.dart';
import 'package:visionguard/features/reminders/application/reminder_hold.dart';
import 'package:visionguard/features/reminders/application/rule_engine.dart';
import 'package:visionguard/features/reminders/application/timer_service.dart';
import 'package:visionguard/features/reminders/data/notification_service.dart';
import 'package:visionguard/features/reminders/domain/reminder.dart';
import 'package:visionguard/features/reminders/presentation/reminder_popup.dart';
import 'package:visionguard/features/settings/application/settings_controller.dart';

import 'database_test.dart' show memoryDb;

final t0 = DateTime(2026, 10, 31, 9);
DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

class FakeNotifier implements SystemNotifier {
  bool available = false;
  int shown = 0;
  int cancelled = 0;
  final _actions = StreamController<String>.broadcast();

  void tap(String actionId) => _actions.add(actionId);

  @override
  Stream<String> get actions => _actions.stream;

  @override
  Future<bool> show({required String title, required String body, required bool sound}) async {
    if (available) shown++;
    return available;
  }

  @override
  Future<void> cancel() async => cancelled++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------- RuleEngine
  group('RuleEngine (§9.5)', () {
    late RuleEngine engine;
    setUp(() => engine = RuleEngine(minDistanceCm: CvConstants.minDistanceDesktopCm));

    test('urutan tipe = prioritas: Istirahat > Jarak > Kedip > 20-20-20', () {
      expect(ReminderType.values.map((r) => r.priority), [1, 2, 3, 4]);
      expect(ReminderType.rest.message, 'Mata tampak lelah. Istirahat 5 menit, yuk.');
      expect(ReminderType.distance.message, 'Posisi terlalu dekat, mundur sedikit.');
      expect(ReminderType.blink.message, 'Kedipkan mata perlahan 10 kali.');
      expect(ReminderType.rule202020.message, 'Lihat objek sejauh 6 meter selama 20 detik.');
    });

    test('semua kondisi bersamaan → kandidat berurutan, top = Istirahat', () {
      // Kondisi jarak & kedip sudah berlangsung > 3 menit.
      engine.observe(at(0), distanceCm: 40, blinkRate: 6);
      final m = ReminderMetrics(
          t: at(200), fatigueScore: 75, distanceCm: 40, blinkRate: 6, rule202020Due: true);
      expect(engine.evaluate(m), ReminderType.values);
      expect(engine.top(m), ReminderType.rest);
    });

    test('skor 59 tidak memicu istirahat, 60 memicu', () {
      expect(engine.top(ReminderMetrics(t: at(0), fatigueScore: 59)), isNull);
      expect(engine.top(ReminderMetrics(t: at(10), fatigueScore: 60)), ReminderType.rest);
    });

    test('jarak harus < ambang terus-menerus 10 detik', () {
      expect(engine.top(ReminderMetrics(t: at(0), distanceCm: 45)), isNull);
      expect(engine.top(ReminderMetrics(t: at(9), distanceCm: 45)), isNull);
      expect(engine.top(ReminderMetrics(t: at(10), distanceCm: 45)), ReminderType.distance);
    });

    test('jarak sempat normal → hitungan durasi diulang', () {
      engine.observe(at(0), distanceCm: 45);
      engine.observe(at(6), distanceCm: 55); // mundur sejenak
      engine.observe(at(7), distanceCm: 45);
      expect(engine.top(ReminderMetrics(t: at(12), distanceCm: 45)), isNull);
      expect(engine.top(ReminderMetrics(t: at(17), distanceCm: 45)), ReminderType.distance);
    });

    test('ambang jarak mobile 30 cm', () {
      final mobile = RuleEngine(minDistanceCm: CvConstants.minDistanceMobileCm);
      mobile.observe(at(0), distanceCm: 35);
      expect(mobile.top(ReminderMetrics(t: at(20), distanceCm: 35)), isNull);
      mobile.observe(at(30), distanceCm: 25);
      expect(mobile.top(ReminderMetrics(t: at(40), distanceCm: 25)), ReminderType.distance);
    });

    test('BR < 10/menit harus bertahan 3 menit; BR null mereset', () {
      engine.observe(at(0), blinkRate: 8);
      expect(engine.top(ReminderMetrics(t: at(179), blinkRate: 8)), isNull);
      expect(engine.top(ReminderMetrics(t: at(180), blinkRate: 8)), ReminderType.blink);

      final e2 = RuleEngine(minDistanceCm: 50);
      e2.observe(at(0), blinkRate: 8);
      e2.observe(at(100)); // BR tidak dilaporkan (frame valid < 70%)
      e2.observe(at(110), blinkRate: 8);
      expect(e2.top(ReminderMetrics(t: at(200), blinkRate: 8)), isNull);
      expect(e2.top(ReminderMetrics(t: at(290), blinkRate: 8)), ReminderType.blink);
      expect(e2.top(ReminderMetrics(t: at(300), blinkRate: 10)), isNull); // tepat 10 bukan < 10
    });

    test('cooldown per jenis: 20 / 5 / 10 menit; 20-20-20 tanpa cooldown', () {
      engine.markShown(ReminderType.rest, at(0));
      engine.markShown(ReminderType.distance, at(0));
      engine.markShown(ReminderType.blink, at(0));
      engine.markShown(ReminderType.rule202020, at(0));
      bool cd(ReminderType r, int s) => engine.inCooldown(r, at(s));

      expect(cd(ReminderType.rest, 20 * 60 - 1), isTrue);
      expect(cd(ReminderType.rest, 20 * 60), isFalse);
      expect(cd(ReminderType.distance, 5 * 60 - 1), isTrue);
      expect(cd(ReminderType.distance, 5 * 60), isFalse);
      expect(cd(ReminderType.blink, 10 * 60 - 1), isTrue);
      expect(cd(ReminderType.blink, 10 * 60), isFalse);
      expect(cd(ReminderType.rule202020, 1), isFalse);
    });

    test('jenis yang cooldown dilewati → prioritas berikutnya tampil', () {
      engine.observe(at(0), distanceCm: 40);
      engine.markShown(ReminderType.rest, at(0));
      final m = ReminderMetrics(t: at(60), fatigueScore: 80, distanceCm: 40);
      expect(engine.top(m), ReminderType.distance);
      // Setelah 20 menit, istirahat kembali menjadi prioritas tertinggi.
      expect(engine.top(ReminderMetrics(t: at(20 * 60), fatigueScore: 80, distanceCm: 40)),
          ReminderType.rest);
    });

    test('cooldown hanya dimulai oleh markShown', () {
      final m = ReminderMetrics(t: at(0), fatigueScore: 70);
      expect(engine.top(m), ReminderType.rest);
      expect(engine.top(ReminderMetrics(t: at(10), fatigueScore: 70)), ReminderType.rest);
      engine.markShown(ReminderType.rest, at(10));
      expect(engine.top(ReminderMetrics(t: at(20), fatigueScore: 70)), isNull);
    });
  });

  // -------------------------------------------------------------- TimerService
  group('TimerService', () {
    test('menghitung waktu layar, jatuh tempo pada interval, reset', () {
      final t = TimerService(interval: const Duration(minutes: 20));
      for (var i = 0; i < 20 * 60 - 1; i++) {
        t.tick();
      }
      expect(t.due, isFalse);
      expect(t.remaining, const Duration(seconds: 1));
      t.tick();
      expect(t.due, isTrue);
      expect(t.screenMinutes, 20);
      expect(t.remaining, Duration.zero);
      t.reset();
      expect(t.due, isFalse);
      expect(t.screenTime, Duration.zero);
    });

    test('interval dapat diubah saat berjalan', () {
      final t = TimerService(interval: const Duration(minutes: 20))..tick(const Duration(minutes: 12));
      t.interval = const Duration(minutes: 10);
      expect(t.due, isTrue);
      t.interval = const Duration(minutes: 30);
      expect(t.remaining, const Duration(minutes: 18));
    });
  });

  // ------------------------------------------------------------- ReminderHold
  group('Tunda & Mode Fokus (ReminderHold)', () {
    test('tunda 15/30/60 menit menahan semua pengingat lalu aktif lagi', () {
      final h = ReminderHold();
      expect(h.isHeld(at(0)), isFalse);
      h.snooze(15, at(0));
      expect(h.isHeld(at(15 * 60 - 1)), isTrue);
      expect(h.isHeld(at(15 * 60)), isFalse);
      expect(h.snoozedUntil(at(15 * 60)), isNull);
      expect(() => h.snooze(20, at(0)), throwsArgumentError);
    });

    test('Mode Fokus dengan durasi pilihan, dapat diakhiri lebih cepat', () {
      final h = ReminderHold();
      h.startFocus(90, at(0));
      expect(h.isHeld(at(89 * 60)), isTrue);
      expect(h.focusUntil(at(0)), at(90 * 60));
      h.endFocus();
      expect(h.isHeld(at(60)), isFalse);
      expect(() => h.startFocus(45, at(0)), throwsArgumentError);
    });

    test('heldUntil memakai penahanan yang paling akhir', () {
      final h = ReminderHold()
        ..snooze(60, at(0))
        ..startFocus(30, at(0));
      expect(h.heldUntil(at(0)), at(60 * 60));
      expect(h.heldUntil(at(60 * 60)), isNull);
    });
  });

  // ------------------------------------------------------------ BreakVerifier
  group('Verifikasi istirahat 20-20-20 (§9.6)', () {
    BreakVerifier run(bool Function(int second) away, {double yaw = 0}) {
      final v = BreakVerifier(start: at(0));
      for (var ms = 0; ms < 20000; ms += 100) {
        final s = ms ~/ 1000;
        final a = away(s);
        v.observe(t: t0.add(Duration(milliseconds: ms)), faceDetected: !a || yaw != 0, yawDeg: a ? yaw : 0);
      }
      v.finish(at(20));
      return v;
    }

    test('wajah hilang ≥ 15 dari 20 detik → terverifikasi', () {
      final v = run((s) => s >= 4); // berpaling sejak detik ke-4 (±16 dtk)
      expect(v.awayTime.inSeconds, inInclusiveRange(15, 16));
      expect(v.verified, isTrue);
    });

    test('hanya berpaling 10 detik → tidak terverifikasi', () {
      final v = run((s) => s >= 10);
      expect(v.verified, isFalse);
    });

    test('|yaw| > 30° dihitung berpaling, tepat 30° tidak', () {
      expect(run((s) => s >= 2, yaw: 45).verified, isTrue);
      expect(run((s) => s >= 2, yaw: -31).verified, isTrue);
      expect(run((s) => s >= 2, yaw: 30).verified, isFalse);
    });
  });

  // -------------------------------------------------------- ReminderController
  group('ReminderService (ReminderController)', () {
    late AppDatabase db;
    late ProviderContainer c;
    late FakeNotifier notifier;
    late DateTime now;
    late Future<int?> session;

    setUp(() async {
      db = memoryDb();
      notifier = FakeNotifier();
      now = t0;
      c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemNotifierProvider.overrideWithValue(notifier),
        reminderClockProvider.overrideWithValue(() => now),
      ]);
      session = c.read(sessionRepositoryProvider).start(SessionMode.ai).then((id) => id);
      await session;
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    ReminderController ctrl() => c.read(reminderControllerProvider.notifier);
    ReminderState st() => c.read(reminderControllerProvider);

    Future<List<Alert>> alerts() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return c.read(alertRepositoryProvider).forSession((await session)!);
    }

    test('Oke → dicatat followed, pop-up ditutup', () async {
      final done = <AlertAction>[];
      expect(ctrl().show(ReminderType.blink, session: session, onDone: (_, a) => done.add(a)), isTrue);
      expect(st().active?.type, ReminderType.blink);
      expect(st().popupVisible, isTrue);
      ctrl().acknowledge();
      expect(st().active, isNull);
      expect(done, [AlertAction.followed]);
      final list = await alerts();
      expect(list.single.type, AlertTypes.blink);
      expect(list.single.action, AlertAction.followed);
    });

    test('hanya satu pengingat sekaligus', () {
      expect(ctrl().show(ReminderType.distance, session: session), isTrue);
      expect(ctrl().canShow, isFalse);
      expect(ctrl().show(ReminderType.rest, session: session), isFalse);
      expect(st().active?.type, ReminderType.distance);
    });

    test('tidak direspons 15 detik → dismissed', () async {
      ctrl().show(ReminderType.rest, session: session);
      ctrl().autoDismissNow();
      expect(st().active, isNull);
      expect((await alerts()).single.action, AlertAction.dismissed);
    });

    test('Tunda 30 menit → snoozed, semua pengingat ditahan, aktif lagi setelahnya', () async {
      ctrl().show(ReminderType.distance, session: session);
      ctrl().snooze(30);
      expect(st().active, isNull);
      expect(st().snoozedUntil, t0.add(const Duration(minutes: 30)));
      expect((await alerts()).single.action, AlertAction.snoozed);

      now = t0.add(const Duration(minutes: 29));
      expect(ctrl().show(ReminderType.rest, session: session), isFalse);
      now = t0.add(const Duration(minutes: 30));
      expect(ctrl().canShow, isTrue);
      expect(ctrl().show(ReminderType.rest, session: session), isTrue);
    });

    test('Mode Fokus menahan pengingat; diakhiri lebih cepat → aktif lagi', () {
      ctrl().startFocus(60);
      expect(st().focusActive, isTrue);
      expect(ctrl().show(ReminderType.rest, session: session), isFalse);
      now = t0.add(const Duration(minutes: 10));
      ctrl().endFocus();
      expect(st().focusActive, isFalse);
      expect(ctrl().show(ReminderType.rest, session: session), isTrue);
    });

    test('20-20-20 Mode AI: berpaling ≥ 15 dtk → terverifikasi, followed', () async {
      final done = <AlertAction>[];
      ctrl().show(ReminderType.rule202020,
          session: session, verifyBreak: true, onDone: (_, a) => done.add(a));
      ctrl().acknowledge();
      expect(st().active?.phase, ReminderPhase.breakCountdown);
      expect(st().active?.breakSecondsLeft, 20);
      for (var s = 0; s < 20; s++) {
        now = at(s);
        ctrl().observeFace(t: now, faceDetected: s < 3, yawDeg: 0);
      }
      now = at(20);
      ctrl().finishBreakNow();
      expect(st().active?.phase, ReminderPhase.breakResult);
      expect(st().active?.breakVerified, isTrue);
      expect(done, [AlertAction.followed]);
      expect((await alerts()).single.action, AlertAction.followed);
      ctrl().closeResult();
      expect(st().active, isNull);
    });

    test('20-20-20 Mode AI: tetap menatap layar → tidak terverifikasi, dismissed', () async {
      ctrl().show(ReminderType.rule202020, session: session, verifyBreak: true);
      ctrl().acknowledge();
      for (var s = 0; s < 20; s++) {
        now = at(s);
        ctrl().observeFace(t: now, faceDetected: true, yawDeg: 5);
      }
      now = at(20);
      ctrl().finishBreakNow();
      expect(st().active?.breakVerified, isFalse);
      expect((await alerts()).single.action, AlertAction.dismissed);
    });

    test('20-20-20 Mode Timer: verifikasi dilewati → followed', () async {
      ctrl().show(ReminderType.rule202020, session: session);
      ctrl().acknowledge();
      now = at(20);
      ctrl().finishBreakNow();
      expect(st().active?.breakVerified, isNull);
      expect((await alerts()).single.action, AlertAction.followed);
    });

    test('pop-up dimatikan & notifikasi gagal → tetap pakai pop-up', () async {
      await c.read(settingsControllerProvider.notifier).setPopup(false);
      ctrl().show(ReminderType.blink, session: session);
      expect(st().popupVisible, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(st().popupVisible, isTrue);
    });

    test('notifikasi tersedia → dikirim; aksi Tunda dari notifikasi', () async {
      notifier.available = true;
      await c.read(settingsControllerProvider.notifier).setPopup(false);
      ctrl().show(ReminderType.blink, session: session);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.shown, 1);
      expect(st().popupVisible, isFalse);
      notifier.tap(NotificationActions.snooze(60));
      await Future<void>.delayed(Duration.zero);
      expect(st().active, isNull);
      expect(st().snoozedUntil, t0.add(const Duration(minutes: 60)));
      expect((await alerts()).single.action, AlertAction.snoozed);
    });

    test('pop-up & notifikasi dimatikan → pengingat tidak tampil', () async {
      await c.read(settingsControllerProvider.notifier).setPopup(false);
      await c.read(settingsControllerProvider.notifier).setNotification(false);
      expect(ctrl().show(ReminderType.rest, session: session), isFalse);
    });
  });

  // ------------------------------------------------------------- Opsi demo
  test('demo "Simulasi terlalu dekat": jarak di bawah ambang desktop & mobile', () async {
    final analyzer = DummyFaceAnalyzer(simulatedFocalPx: 600)..simulateTooClose = true;
    final est = DistanceEstimator(focalLengthPx: 600);
    double? d;
    for (var i = 0; i < 45; i++) {
      final f = CameraFrame(width: 640, height: 480, timestamp: t0.add(Duration(milliseconds: i * 66)));
      d = est.update(await analyzer.analyze(f));
    }
    expect(d, lessThan(CvConstants.minDistanceMobileCm));
    expect(d, lessThan(CvConstants.minDistanceDesktopCm));
  });

  // ------------------------------------------------ MonitoringController + 20-20-20
  group('Integrasi Mode Timer', () {
    test('TimerService memicu 20-20-20, istirahat selesai → timer direset', () async {
      final db = memoryDb();
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemNotifierProvider.overrideWithValue(FakeNotifier()),
      ]);
      final m = c.read(monitoringControllerProvider.notifier);
      m.useTimerMode();
      m.setFast202020(true); // opsi debug: interval 1 menit
      expect(c.read(monitoringControllerProvider).secondsToNext202020, 60);
      for (var i = 0; i < 60; i++) {
        m.tickScreenTimer();
      }
      final r = c.read(reminderControllerProvider.notifier);
      expect(c.read(reminderControllerProvider).active?.type, ReminderType.rule202020);
      expect(c.read(reminderControllerProvider).active?.verifyBreak, isFalse);
      r.acknowledge();
      r.finishBreakNow();
      expect(m.screenTimer.screenTime, Duration.zero);
      expect(c.read(monitoringControllerProvider).secondsToNext202020, 60);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final rows = await db.select(db.alerts).get();
      expect(rows.single.type, AlertTypes.rule202020);
      expect(rows.single.action, AlertAction.followed);
      await m.stop();
      c.dispose();
      await db.close();
    });
  });

  // ------------------------------------------------------------------ Pop-up UI
  group('Pop-up pengingat (S-05)', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      final c = ProviderContainer(overrides: [
        systemNotifierProvider.overrideWithValue(FakeNotifier()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => ReminderOverlay(child: child!),
          home: const Scaffold(body: TextField(autofocus: true)),
        ),
      ));
      return c;
    }

    testWidgets('pojok kanan bawah, Oke/Tunda, tidak mengambil fokus, hilang 15 dtk', (tester) async {
      final c = await pump(tester);
      await tester.pump();
      final field = FocusManager.instance.primaryFocus;
      c.read(reminderControllerProvider.notifier).show(ReminderType.distance);
      await tester.pump();

      expect(find.text('Posisi terlalu dekat, mundur sedikit.'), findsOneWidget);
      expect(find.text('Oke'), findsOneWidget);
      expect(find.text('Tunda'), findsOneWidget);
      final popup = tester.getRect(find.byType(ReminderPopup));
      final screen = tester.getRect(find.byType(Scaffold));
      expect(popup.right, closeTo(screen.right - 16, 1));
      expect(popup.bottom, closeTo(screen.bottom - 16, 1));
      expect(find.ancestor(of: find.byType(ReminderPopup), matching: find.byType(ExcludeFocus)),
          findsOneWidget);

      await tester.tap(find.text('Tunda'));
      await tester.pump();
      for (final m in CvConstants.snoozeOptionsMin) {
        expect(find.text('$m menit'), findsOneWidget);
      }
      expect(FocusManager.instance.primaryFocus, field);

      await tester.pump(CvConstants.reminderAutoDismiss);
      expect(find.byType(ReminderPopup), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('20-20-20: Oke memulai hitung mundur 20 detik', (tester) async {
      final c = await pump(tester);
      c.read(reminderControllerProvider.notifier).show(ReminderType.rule202020);
      await tester.pump();
      await tester.tap(find.text('Oke'));
      await tester.pump();
      expect(find.text('20 detik'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('15 detik'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      expect(find.textContaining('Istirahat selesai'), findsOneWidget);
      await tester.pump(CvConstants.breakResultVisible);
      expect(find.byType(ReminderPopup), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });
}
