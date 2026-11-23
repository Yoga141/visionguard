import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Peristiwa layar ponsel dari `MainActivity.kt` (BroadcastReceiver
/// ACTION_SCREEN_OFF / ACTION_SCREEN_ON).
enum ScreenEvent { off, on }

/// Aliran peristiwa layar. Kosong di selain Android.
final screenEventsProvider = Provider<Stream<ScreenEvent>>((ref) {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      Platform.environment.containsKey('FLUTTER_TEST')) {
    return const Stream.empty();
  }
  const channel = EventChannel('visionguard/screen_state');
  return channel
      .receiveBroadcastStream()
      .map((e) => e == 'off' ? ScreenEvent.off : ScreenEvent.on)
      .handleError((Object e) => debugPrint('Status layar tidak tersedia: $e'));
});
