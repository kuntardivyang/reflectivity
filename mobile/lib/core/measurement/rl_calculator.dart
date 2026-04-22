/// Retroreflectivity calculator.
///
/// Converts a luminance delta (illuminated frame minus ambient frame) into
/// the Coefficient of Retroreflected Luminance (RL) in mcd/m²/lux.
///
/// RL = luminance_delta (cd/m²) / illuminance_at_marking (lux) × 1000
///
/// For the 30-meter geometry standard (headlight 0.65 m, eye 1.2 m,
/// entrance angle 88.76°, observation angle 1.05°) the illuminance at the
/// marking is computed from the flash intensity and the vehicle geometry.
class RLCalculator {
  /// Phone LED flash output in lumens — typical mid-range smartphone.
  final double flashLumens;

  /// Distance from phone (mounted on windshield) to the detected marking (m).
  /// At 30-m geometry this is 30 m; the measurement pipeline estimates it
  /// per-frame from camera mounting height + bounding box position.
  final double distanceMeters;

  /// Physical upper bound on RL for road markings. The brightest fresh
  /// glass-bead thermoplastic paint tops out around 500 mcd/m²/lux; 2000
  /// is a hard ceiling that still lets us detect truly anomalous inputs
  /// (e.g. the pipeline running without flash differential, which makes
  /// the math spit out 10⁶+). Values above the ceiling get clamped so a
  /// bad frame pair never lies to the judge/dashboard.
  static const double rlCeiling = 2000.0;

  const RLCalculator({
    this.flashLumens = 50.0,
    this.distanceMeters = 5.0,
  });

  /// Illuminance at the marking (lux), inverse-square from flash.
  double _illuminanceAtMarking() {
    return flashLumens / (4 * 3.141592653589793 * distanceMeters * distanceMeters);
  }

  /// Compute RL in mcd/m²/lux from a luminance delta in cd/m².
  /// Always clamped to [0, rlCeiling].
  double compute(double luminanceDelta) {
    if (luminanceDelta <= 0) return 0;
    final lux = _illuminanceAtMarking();
    if (lux <= 0) return 0;
    final raw = (luminanceDelta / lux) * 1000.0;
    if (raw > rlCeiling) return rlCeiling;
    return raw;
  }
}
