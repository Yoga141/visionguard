/// Konstanta aturan bisnis kredit & statistik (DOCS_SPEC §8.1, UC-16/17).
///
/// Konstanta CV & ambang pengingat tetap hanya di `cv_constants.dart`.
class BusinessConstants {
  BusinessConstants._();

  // ---- §8.1 Freemium & kredit ----
  /// Kuota gratis Hari Pemantauan AI per bulan berjalan.
  static const int freeDaysPerMonth = 2;

  /// 1 kredit = 1 Hari Pemantauan AI.
  static const int creditsPerDay = 1;

  // ---- UC-17 Grafik tren ----
  static const List<int> trendRangesDays = [7, 30];

  /// Grafik tren butuh data minimal 2 hari (alur alternatif UC-17).
  static const int trendMinDays = 2;

  /// Jumlah hari data contoh untuk demo grafik (hanya mode debug).
  static const int demoSeedDays = 14;
}
