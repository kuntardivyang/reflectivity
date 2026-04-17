import 'package:flutter_test/flutter_test.dart';
import 'package:reflectscan/core/measurement/oecf_calibrator.dart';

void main() {
  group('OECFCalibrator.defaultCurve', () {
    final calibrator = OECFCalibrator.defaultCurve();

    test('black pixel maps to zero luminance', () {
      expect(calibrator.pixelToLuminance(0), 0);
    });

    test('white pixel maps to top of range (~1000 cd/m²)', () {
      expect(calibrator.pixelToLuminance(255), closeTo(1000, 0.001));
    });

    test('midtone is well below midpoint due to gamma 2.2', () {
      final v = calibrator.pixelToLuminance(128);
      expect(v, greaterThan(0));
      expect(v, lessThan(300));
    });

    test('curve is monotonically non-decreasing', () {
      double prev = -1;
      for (int i = 0; i < 256; i++) {
        final v = calibrator.pixelToLuminance(i);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });

    test('out-of-range pixel values are clamped', () {
      expect(calibrator.pixelToLuminance(-5), 0);
      expect(calibrator.pixelToLuminance(999), closeTo(1000, 0.001));
    });
  });

  group('OECFCalibrator.meanLuminance', () {
    final calibrator = OECFCalibrator.defaultCurve();

    test('empty input returns 0', () {
      expect(calibrator.meanLuminance(const []), 0);
    });

    test('uniform white ROI produces ~1000 cd/m²', () {
      final pixels = List.filled(100, 255);
      expect(calibrator.meanLuminance(pixels), closeTo(1000, 0.001));
    });

    test('uniform black ROI produces 0 cd/m²', () {
      final pixels = List.filled(100, 0);
      expect(calibrator.meanLuminance(pixels), 0);
    });
  });

  group('OECFCalibrator.fromTable', () {
    test('uses provided lookup values exactly', () {
      final table = List<double>.generate(256, (i) => i.toDouble());
      final c = OECFCalibrator.fromTable(table);
      expect(c.pixelToLuminance(0), 0);
      expect(c.pixelToLuminance(100), 100);
      expect(c.pixelToLuminance(255), 255);
    });
  });
}
