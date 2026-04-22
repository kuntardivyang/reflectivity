import 'package:flutter/material.dart';

import '../config.dart';

enum SafetyStatus { safe, warning, critical, uncalibrated }

extension SafetyStatusX on SafetyStatus {
  String get label {
    switch (this) {
      case SafetyStatus.safe:         return 'SAFE';
      case SafetyStatus.warning:      return 'WARNING';
      case SafetyStatus.critical:     return 'CRITICAL';
      case SafetyStatus.uncalibrated: return 'UNCAL';
    }
  }

  Color get color {
    switch (this) {
      case SafetyStatus.safe:         return const Color(0xFF22C55E);  // green
      case SafetyStatus.warning:      return const Color(0xFFFBBF24);  // yellow
      case SafetyStatus.critical:     return const Color(0xFFEF4444);  // red
      case SafetyStatus.uncalibrated: return const Color(0xFF94A3B8);  // slate
    }
  }
}

class SafetyClassifier {
  /// Classify an RL value (mcd/m²/lux) into a safety status.
  ///
  /// [calibrated] must be true for the value to be classified against
  /// thresholds. When the measurement pipeline can't produce a flash
  /// differential (torch disabled or daylight drowning out flash), the
  /// RL number has no physical meaning and we return [uncalibrated] so
  /// the UI/dashboard/backend do not mistakenly label a random frame as
  /// SAFE.
  ///
  /// Thresholds from *Impact of Road Marking Retroreflectivity on
  /// Machine Vision in Dry Conditions* (PMC8963044, 2022).
  static SafetyStatus classify(double rl, {bool calibrated = true}) {
    if (!calibrated) return SafetyStatus.uncalibrated;
    if (rl > AppConfig.rlSafeThreshold) return SafetyStatus.safe;
    if (rl > AppConfig.rlWarningThreshold) return SafetyStatus.warning;
    return SafetyStatus.critical;
  }
}
