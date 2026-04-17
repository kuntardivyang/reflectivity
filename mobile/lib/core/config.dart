class AppConfig {
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  // Retroreflectivity thresholds (mcd/m²/lux)
  static const double rlSafeThreshold = 100.0;
  static const double rlWarningThreshold = 54.0;

  // Measurement sampling
  static const int flashHz = 40;
  static const int gpsHz = 1;
  static const int detectionTargetFps = 15;

  // Upload behavior
  static const int uploadBatchSize = 500;
  static const Duration uploadRetryDelay = Duration(seconds: 5);
}
