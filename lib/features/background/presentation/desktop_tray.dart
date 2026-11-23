import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart' as win;

import '../../../app/router.dart';
import '../../auth/application/auth_controller.dart';
import '../../monitoring/application/monitoring_controller.dart';
import '../../reminders/application/reminder_controller.dart';
import '../../reminders/data/notification_service.dart';
import '../application/app_visibility.dart';
import '../application/tray_actions.dart';
import '../application/tray_menu.dart';

/// System tray Windows (S-11, PMT-06).
///
/// - Tombol tutup jendela → jendela disembunyikan ke tray; pemantauan tetap
///   jalan dan pengingat dikirim lewat notifikasi sistem.
/// - Klik ikon tray → jendela tampil lagi. Klik kanan → menu.
/// - Menu dibangun ulang dari [buildTrayMenu] setiap status berubah.
class DesktopTray {
  DesktopTray(this._container);

  final ProviderContainer _container;
  tray.TrayIcon? _icon;
  win.Window? _window;
  final _subs = <ProviderSubscription<Object?>>[];
  bool _hintShown = false;
  bool _quitting = false;

  static const iconAsset = 'assets/tray/tray_icon.ico';

  static bool get supported =>
      !kIsWeb && Platform.isWindows && !Platform.environment.containsKey('FLUTTER_TEST');

  late final TrayActions _actions = TrayActions(<T>(p) => _container.read(p));

  /// Memasang ikon tray & penangan tutup jendela. Gagal → aplikasi tetap
  /// berjalan seperti biasa (menutup jendela = keluar).
  Future<void> init({bool startHidden = false}) async {
    try {
      final window = win.WindowManager.instance.getCurrent();
      final icon = tray.TrayIcon.create();
      if (window == null || icon == null) return;
      _window = window;
      _icon = icon;
      icon.icon = tray.ImageAsset.fromAsset(iconAsset);
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      icon.addListener((e) {
        if (e is tray.TrayIconClickedEvent || e is tray.TrayIconDoubleClickedEvent) showWindow();
      });
      icon.setVisible(true);
      window.addListener((e) {
        if (e is win.WindowCloseRequestedEvent && !_quitting) {
          e.request.cancel();
          hideToTray();
        }
      });
      _subs
        ..add(_container.listen(monitoringControllerProvider, (_, __) => _rebuild()))
        ..add(_container.listen(reminderControllerProvider, (_, __) => _rebuild()))
        ..add(_container.listen(authControllerProvider, (_, __) => _rebuild()));
      _rebuild();
      if (startHidden) hideToTray(showHint: false);
    } catch (e) {
      debugPrint('System tray tidak tersedia: $e');
    }
  }

  void hideToTray({bool showHint = true}) {
    _window?.hide();
    _container.read(appInBackgroundProvider.notifier).state = true;
    if (showHint && !_hintShown) {
      _hintShown = true;
      unawaited(_container.read(systemNotifierProvider).show(
            title: 'VisionGuard tetap berjalan',
            body: 'Pemantauan berlanjut di system tray. Klik ikon VisionGuard untuk membuka lagi.',
            sound: false,
          ));
    }
  }

  void showWindow() {
    final w = _window;
    if (w == null) return;
    if (w.isMinimized) w.restore();
    w.show();
    w.focus();
    _container.read(appInBackgroundProvider.notifier).state = false;
  }

  void _rebuild() {
    final icon = _icon;
    if (icon == null) return;
    final m = _container.read(monitoringControllerProvider);
    final r = _container.read(reminderControllerProvider);
    final entries = buildTrayMenu(
      monitoring: m,
      reminders: r,
      loggedIn: _container.read(authControllerProvider).isLoggedIn,
    );
    icon.setTooltip('VisionGuard — ${trayStatus(m, r)}');
    final menu = _buildMenu(entries);
    if (menu != null) icon.setContextMenu(menu);
  }

  tray.Menu? _buildMenu(List<TrayEntry> entries) {
    final menu = tray.Menu.create();
    if (menu == null) return null;
    for (final e in entries) {
      if (e.separator) {
        menu.addSeparator();
        continue;
      }
      final item = tray.MenuItem.createWithLabelAndType(
          e.label, e.children.isEmpty ? tray.MenuItemType.normal : tray.MenuItemType.submenu);
      if (item == null) continue;
      item.isEnabled = e.enabled;
      if (e.children.isNotEmpty) item.submenu = _buildMenu(e.children);
      final action = e.action;
      if (action != null) {
        item.addListener((ev) {
          if (ev is tray.MenuItemClickedEvent) unawaited(_onAction(action, e.focusMinutes));
        });
      }
      menu.addItem(item);
    }
    return menu;
  }

  Future<void> _onAction(TrayAction action, int? focusMinutes) async {
    switch (action) {
      case TrayAction.openDashboard:
        showWindow();
        _container.read(routerProvider).go(Routes.dashboard);
      case TrayAction.logout:
        await _actions.run(action);
        showWindow();
        _container.read(routerProvider).go(Routes.login);
      case TrayAction.quit:
        _quitting = true;
        await _actions.run(action); // menutup sesi `sessions` dengan rapi
        dispose();
        exit(0);
      default:
        await _actions.run(action, focusMinutes: focusMinutes);
    }
  }

  void dispose() {
    for (final s in _subs) {
      s.close();
    }
    _subs.clear();
    _icon?.dispose();
    _icon = null;
  }
}
