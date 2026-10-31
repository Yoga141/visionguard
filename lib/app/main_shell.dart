import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/monitoring/application/monitoring_controller.dart';
import '../shared/widgets/camera_active_badge.dart';

/// Kerangka menu utama (DOCS_SPEC §7.4): Dashboard, Statistik, Kredit,
/// Pengaturan. Layar sempit (mobile) memakai bottom navigation, layar lebar
/// (desktop) memakai navigation rail.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Lebar minimum untuk beralih ke navigation rail.
  static const railBreakpoint = 720.0;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.bar_chart_outlined, selected: Icons.bar_chart, label: 'Statistik'),
    (icon: Icons.account_balance_wallet_outlined, selected: Icons.account_balance_wallet, label: 'Kredit'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Pengaturan'),
  ];

  void _go(int index) =>
      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraActive = ref.watch(monitoringControllerProvider.select((m) => m.cameraActive));
    // PRV-03: indikator kamera tetap terlihat di menu lain selama kamera menyala
    // (Dashboard sudah menampilkannya di AppBar).
    final body = Column(
      children: [
        if (cameraActive && navigationShell.currentIndex != 0)
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(alignment: Alignment.centerRight, child: CameraActiveBadge()),
            ),
          ),
        Expanded(child: navigationShell),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= railBreakpoint) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _go,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      }
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
          ],
        ),
      );
    });
  }
}
