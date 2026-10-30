import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Titik masuk aplikasi VisionGuard.
///
/// Urutan inisialisasi:
/// 1. [WidgetsFlutterBinding] — agar binding Flutter siap.
/// 2. [dotenv.load] — memuat `.env` (GEMINI_API_KEY untuk fitur Saran AI,
///    khusus pengembangan; lihat DOCS_SPEC §17).
/// 3. [runApp] — menjalankan aplikasi di dalam [ProviderScope] agar semua
///    provider Riverpod dapat diakses dari mana saja.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  runApp(const ProviderScope(child: VisionGuardApp()));
}
