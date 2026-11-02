/// TimerService (SDD 4.1, Seq 4.23): menghitung waktu layar kontinu untuk
/// aturan 20-20-20. Dipakai di Mode AI (tidak bertambah saat wajah hilang,
/// PMT-05) maupun Mode Timer.
///
/// Murni (tanpa `Timer`): pemanggil memanggil [tick] tiap detik.
class TimerService {
  TimerService({required this.interval});

  /// Interval 20-20-20 dari Pengaturan (D10), dapat diubah saat berjalan.
  Duration interval;

  Duration _screen = Duration.zero;

  /// Waktu layar kontinu sejak reset terakhir.
  Duration get screenTime => _screen;

  int get screenMinutes => _screen.inMinutes;

  /// Sisa waktu menuju pengingat 20-20-20 (tidak negatif).
  Duration get remaining => _screen >= interval ? Duration.zero : interval - _screen;

  /// Interval sudah tercapai → pengingat 20-20-20 jatuh tempo.
  bool get due => _screen >= interval;

  void tick([Duration dt = const Duration(seconds: 1)]) => _screen += dt;

  /// Dipanggil setelah istirahat 20-20-20 (atau pengingatnya diabaikan).
  void reset() => _screen = Duration.zero;
}
