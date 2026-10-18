import 'package:flutter/material.dart';

/// Tema aplikasi: bersih, minimalis, mendukung mode terang dan gelap
/// (SRS 3.1 poin 2 - Standar Tampilan).
class AppTheme {
  static const seed = Color(0xFF1F7A6D);

  // Warna status skor kelelahan. Selalu dipasangkan dengan label teks
  // agar tidak bergantung pada warna saja.
  static const normal = Color(0xFF2E9E5B);
  static const waspada = Color(0xFFE0A100);
  static const lelah = Color(0xFFD64545);

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
