import 'package:flutter_test/flutter_test.dart';
import 'package:reflectscan/core/measurement/rl_calculator.dart';

void main() {
  group('RLCalculator.compute', () {
    test('returns 0 for zero or negative luminance delta', () {
      const c = RLCalculator();
      expect(c.compute(0), 0);
      expect(c.compute(-50), 0);
    });

    test('returns positive RL for positive luminance delta', () {
      const c = RLCalculator();
      expect(c.compute(100), greaterThan(0));
    });

    test('RL scales linearly with luminance delta', () {
      const c = RLCalculator();
      final rlLow = c.compute(50);
      final rlHigh = c.compute(100);
      expect(rlHigh, closeTo(rlLow * 2, 0.001));
    });

    test('shorter distance produces higher RL for same delta', () {
      const near = RLCalculator(distanceMeters: 3);
      const far  = RLCalculator(distanceMeters: 10);
      expect(near.compute(100), greaterThan(far.compute(100)));
    });

    test('zero flash lumens yields zero RL', () {
      const c = RLCalculator(flashLumens: 0);
      expect(c.compute(100), 0);
    });
  });
}
