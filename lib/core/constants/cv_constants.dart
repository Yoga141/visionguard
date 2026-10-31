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
  static const double tauFactor = 0.7; // τ = 0,7 × baseline EAR (sensitivitas Sedang)
  // Pemetaan sensitivitas → faktor τ (DOCS_SPEC §16 #5). Makin tinggi τ, makin
  // mudah mata dianggap tertutup.
  static const double tauFactorLow = 0.65; // Rendah
  static const double tauFactorHigh = 0.75; // Tinggi
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
  /// Lebar iris dihaluskan dengan median 1 detik (DFD 3.5.3, DOCS_SPEC §16 #6).
  static const Duration irisMedianWindow = Duration(seconds: 1);

  // ---- 2.5.3: Skor kelelahan (bobot 50:30:20) ----
  static const double wBlink = 0.5;
  static const double wPerclos = 0.3;
  static const double wTime = 0.2;
  static const double perclosMax = 0.15;
  static const double screenMinutesMax = 60;
  /// Level: 0–39 Normal, 40–59 Waspada, 60–100 Lelah.
  static const int levelWaspadaMin = 40;
  static const int levelLelahMin = 60;
  /// PERCLOS & skor dievaluasi tiap 10 detik, bukan per frame (PMT-04, §16 #7).
  static const Duration scoreInterval = Duration(seconds: 10);
  /// Perhitungan dijeda bila wajah tidak terdeteksi lebih dari ini (PMT-05).
  static const Duration faceLostPause = Duration(seconds: 10);

  // ---- 2.5.4 / Tabel 2.6: Ambang pengingat ----
  static const double minDistanceDesktopCm = 50; // pengingat jarak
  static const double minDistanceMobileCm = 30;
  static const double lowBlinkRatePerMin = 10; // pengingat kedip
  /// Interval 20-20-20 (menit): bawaan & batas pengaturan (PGT-01, §16 #4).
  static const int rule202020DefaultMin = 20;
  static const int rule202020MinMin = 10;
  static const int rule202020MaxMin = 60;

  /// Jumlah landmark yang dihasilkan MediaPipe Face Landmarker (dengan iris).
  static const int landmarkCount = 478;
}
