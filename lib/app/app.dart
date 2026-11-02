import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reminders/presentation/reminder_popup.dart';
import 'router.dart';
import 'theme.dart';

class VisionGuardApp extends ConsumerWidget {
  const VisionGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'VisionGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Pop-up pengingat (S-05) tampil di atas semua layar.
      builder: (context, child) => ReminderOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
