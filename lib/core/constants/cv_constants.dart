/// Konstanta CV Engine, diambil dari SDD Bab 2.5.
/// Semua nilai adalah nilai awal dan dapat disesuaikan setelah pengujian.
class CvConstants {
  CvConstants._();

  // ---- 2.5 Umum ----
  static const int frameWidth = 640;
  static const int frameHeight = 480;
  static const int targetFpsDesktop = 15;
  static const int targetFpsMobile = 10;
  static const double maxHeadYawDeg = 30; // frame tidak valid jika lebih

  // ---- 2.5.1 / Tabel 2.4: Landmark mata (MediaPipe Face Mesh) ----
  /// Urutan p1..p6: p1 & p4 sudut mata, p2 & p3 kelopak atas, p5 & p6 kelopak bawah.
  static const List<int> rightEye = [33, 160, 158, 133, 153, 144];
  static const List<int> leftEye = [362, 385, 387, 263, 373, 380];

  static const int earSmoothingFrames = 3;
  static const double tauFactor = 0.7; // τ = 0,7 × baseline EAR
  static const int blinkMinMs = 100;
  static const int blinkMaxMs = 400;
  static const Duration metricWindow = Duration(seconds: 60);
  static const double minValidFrameRatio = 0.70;
  static const Duration eyeCalibrationDuration = Duration(seconds: 10);

  // ---- 2.5.2: Estimasi jarak dengan diameter iris ----
  static const double irisDiameterMm = 11.7;
  static const int rightIrisA = 469, rightIrisB = 471;
  static const int leftIrisA = 474, leftIrisB = 476;
  static const double refDistanceDesktopMm = 500;
  static const double refDistanceMobileMm = 300;
  static const double fallbackFovDeg = 60;
  static const Duration distanceCalibrationDuration = Duration(seconds: 5);

  // ---- 2.5.3: Skor kelelahan (bobot 50:30:20) ----
  static const double wBlink = 0.5;
  static const double wPerclos = 0.3;
  static const double wTime = 0.2;
  static const double perclosMax = 0.15;
  static const double screenMinutesMax = 60;

  /// Jumlah landmark yang dihasilkan MediaPipe Face Landmarker (dengan iris).
  static const int landmarkCount = 478;
}
