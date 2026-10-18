import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Titik masuk aplikasi VisionGuard.
///
/// [ProviderScope] membungkus seluruh aplikasi agar semua provider Riverpod
/// (auth, kalibrasi, pemantauan, CV engine) dapat diakses dari mana saja.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VisionGuardApp()));
}
