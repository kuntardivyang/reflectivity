class AppConfig {
  // LAN IP of the laptop running FastAPI. For an emulator use 10.0.2.2;
  // for a physical phone on the same Wi-Fi use the laptop IPv4 shown by
  // `hostname -I` on Linux or `ipconfig getifaddr en0` on macOS.
  static const String apiBaseUrl = 'https://reflectivity-production.up.railway.app';

  // Retroreflectivity thresholds (mcd/m²/lux)
  static const double rlSafeThreshold = 100.0;
  static const double rlWarningThreshold = 54.0;

  // Measurement sampling.
  //
  // flashHz is the strobe frequency: one ON and one OFF pulse per cycle.
  // Real hardware torch APIs (Android torch_light, iOS AVCaptureDevice) can
  // reliably toggle at ~2-4 Hz. At 10 Hz+ the underlying call queues or
  // errors, and at 40 Hz the LED gets stuck after 1-2 blinks. We keep it
  // low on purpose: the measurement math only needs a few paired frames
  // per second to produce a smooth RL stream.
  static const int flashHz = 2;
  static const int gpsHz = 1;
  static const int detectionTargetFps = 15;

  /// Minimum gap between persisted measurements, regardless of frame rate.
  /// Prevents the SQLite write path from getting overwhelmed while still
  /// giving the UI visible feedback.
  static const Duration minCaptureInterval = Duration(milliseconds: 800);

  // Upload behavior
  static const int uploadBatchSize = 500;
  static const Duration uploadRetryDelay = Duration(seconds: 5);
}
