import 'package:flutter/material.dart';

import '../config.dart';

enum SafetyStatus { safe, warning, critical }

extension SafetyStatusX on SafetyStatus {
  String get label {
    switch (this) {
      case SafetyStatus.safe:     return 'SAFE';
      case SafetyStatus.warning:  return 'WARNING';
      case SafetyStatus.critical: return 'CRITICAL';
    }
  }

  Color get color {
    switch (this) {
      case SafetyStatus.safe:     return const Color(0xFF22C55E);  // green
      case SafetyStatus.warning:  return const Color(0xFFFBBF24);  // yellow
      case SafetyStatus.critical: return const Color(0xFFEF4444);  // red
    }
  }
}

class SafetyClassifier {
  /// Classify an RL value (mcd/m²/lux) into a safety status.
  ///
  /// Thresholds from *Impact of Road Marking Retroreflectivity on
  /// Machine Vision in Dry Conditions* (PMC8963044, 2022).
  static SafetyStatus classify(double rl) {
    if (rl > AppConfig.rlSafeThreshold) return SafetyStatus.safe;
    if (rl > AppConfig.rlWarningThreshold) return SafetyStatus.warning;
    return SafetyStatus.critical;
  }
}
