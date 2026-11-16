import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../application/auth_controller.dart';
import 'post_login.dart';

/// Layar pembuka: auto-login dari token tersimpan (`GET /me`).
/// Tidak ada sesi / token tidak berlaku → Login.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final ok = await ref.read(authControllerProvider.notifier).restoreSession();
    if (!mounted) return;
    if (!ok) {
      context.go(Routes.login);
      return;
    }
    if (ref.read(authControllerProvider).offline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Offline: masuk memakai sesi tersimpan. Fitur server aktif lagi saat online.'),
      ));
    }
    goAfterSignIn(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_red_eye_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Memuat sesi...'),
          ],
        ),
      ),
    );
  }
}
