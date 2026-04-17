import 'dart:math' as math;

/// Opto-Electronic Conversion Function calibrator.
///
/// Converts raw camera pixel values (0–255 after gamma) to physical luminance
/// in cd/m² using a lookup table built from a calibration chart.
///
/// For the hackathon demo we ship with a default response curve approximating
/// a typical smartphone sensor at auto-exposure. A per-device calibration
/// routine can replace [_defaultTable] with measured values for absolute
/// accuracy (see `calibrate()`).
class OECFCalibrator {
  /// Pixel value (0–255) → luminance (cd/m²) lookup.
  final List<double> _table;

  OECFCalibrator._(this._table);

  /// Ship-default curve: `L = (px / 255)^2.2 * 1000`, covering 0–1000 cd/m².
  factory OECFCalibrator.defaultCurve() {
    final table = List<double>.generate(
      256,
      (i) => math.pow(i / 255.0, 2.2).toDouble() * 1000.0,
    );
    return OECFCalibrator._(table);
  }

  /// Build a calibrator from a measured lookup table (length 256).
  factory OECFCalibrator.fromTable(List<double> table) {
    assert(table.length == 256, 'OECF table must have 256 entries');
    return OECFCalibrator._(List.unmodifiable(table));
  }

  /// Convert a single pixel value to luminance in cd/m².
  double pixelToLuminance(int pixel) {
    final clamped = pixel.clamp(0, 255);
    return _table[clamped];
  }

  /// Convert an iterable of pixel values to mean luminance (cd/m²).
  double meanLuminance(Iterable<int> pixels) {
    double sum = 0;
    int count = 0;
    for (final p in pixels) {
      sum += pixelToLuminance(p);
      count++;
    }
    if (count == 0) return 0;
    return sum / count;
  }
}
