import '../../../core/constants/cv_constants.dart';

/// Verifikasi istirahat 20-20-20 (DOCS_SPEC §9.6, UC-14, PNG-05).
///
/// Selama hitung mundur 20 detik, setiap hasil FaceAnalyzer dilaporkan ke
/// [observe]. Pengguna dianggap berpaling bila wajah **tidak terdeteksi**
/// atau **|yaw| > 30°**. Istirahat **terverifikasi** jika total waktu berpaling
/// ≥ 15 detik. Hanya status wajah & sudut yang dipakai, bukan frame.
class BreakVerifier {
  BreakVerifier({required DateTime start}) : _last = start;

  DateTime _last;

  /// Status sebelum frame pertama: belum ada bukti berpaling.
  bool _away = false;
  Duration _awayTime = Duration.zero;

  static bool isAway({required bool faceDetected, required double yawDeg}) =>
      !faceDetected || yawDeg.abs() > CvConstants.maxHeadYawDeg;

  /// Interval sejak observasi sebelumnya dinilai memakai status sebelumnya.
  void observe({required DateTime t, required bool faceDetected, required double yawDeg}) {
    _accumulate(t);
    _away = isAway(faceDetected: faceDetected, yawDeg: yawDeg);
  }

  /// Menutup interval terakhir saat hitung mundur selesai.
  void finish(DateTime end) => _accumulate(end);

  Duration get awayTime => _awayTime;

  bool get verified => _awayTime >= CvConstants.breakVerifyMin;

  void _accumulate(DateTime t) {
    if (!t.isAfter(_last)) return;
    if (_away) _awayTime += t.difference(_last);
    _last = t;
  }
}
