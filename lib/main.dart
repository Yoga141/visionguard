import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

/// Titik masuk aplikasi VisionGuard.
///
/// Urutan inisialisasi:
/// 1. [WidgetsFlutterBinding] — agar binding Flutter siap.
/// 2. [dotenv.load] — memuat variabel environment dari file `.env`
///    (termasuk GEMINI_API_KEY).
/// 3. [Firebase.initializeApp] — menggunakan konfigurasi dari
///    [DefaultFirebaseOptions] (dibuat oleh FlutterFire CLI).
/// 4. [runApp] — menjalankan aplikasi di dalam [ProviderScope] agar semua
///    provider Riverpod dapat diakses dari mana saja.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: VisionGuardApp()));
}
