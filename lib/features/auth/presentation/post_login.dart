import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../calibration/application/calibration_controller.dart';
import '../../stats/application/sync_service.dart';
import '../application/auth_controller.dart';

/// UC-02 langkah 5 (juga setelah auto-login): belum setuju privasi →
/// onboarding; belum kalibrasi → kalibrasi; selain itu Dashboard.
/// Ringkasan harian yang belum terkirim disinkronkan di belakang (STK-03).
void goAfterSignIn(BuildContext context, WidgetRef ref) {
  unawaited(ref.read(syncServiceProvider).syncPending());

  final auth = ref.read(authControllerProvider);
  final calibrated = ref.read(calibrationControllerProvider).isComplete;
  if (!auth.privacyAccepted) {
    context.go(Routes.onboarding);
  } else if (!calibrated) {
    context.go(Routes.calibration);
  } else {
    context.go(Routes.dashboard);
  }
}
