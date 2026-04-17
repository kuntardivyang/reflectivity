import 'package:flutter_test/flutter_test.dart';
import 'package:reflectscan/core/measurement/safety_classifier.dart';

void main() {
  group('SafetyClassifier.classify', () {
    test('0 mcd/m²/lux is CRITICAL', () {
      expect(SafetyClassifier.classify(0), SafetyStatus.critical);
    });

    test('values at and below 54 are CRITICAL', () {
      expect(SafetyClassifier.classify(53.9), SafetyStatus.critical);
      expect(SafetyClassifier.classify(54.0), SafetyStatus.critical);
    });

    test('values just above 54 become WARNING', () {
      expect(SafetyClassifier.classify(54.1), SafetyStatus.warning);
      expect(SafetyClassifier.classify(75), SafetyStatus.warning);
      expect(SafetyClassifier.classify(100.0), SafetyStatus.warning);
    });

    test('values above 100 are SAFE', () {
      expect(SafetyClassifier.classify(100.1), SafetyStatus.safe);
      expect(SafetyClassifier.classify(250), SafetyStatus.safe);
      expect(SafetyClassifier.classify(4000), SafetyStatus.safe);
    });
  });

  group('SafetyStatus labels and colors', () {
    test('labels match backend schema strings', () {
      expect(SafetyStatus.safe.label, 'SAFE');
      expect(SafetyStatus.warning.label, 'WARNING');
      expect(SafetyStatus.critical.label, 'CRITICAL');
    });

    test('each status has a distinct color', () {
      final colors = {
        SafetyStatus.safe.color.toARGB32(),
        SafetyStatus.warning.color.toARGB32(),
        SafetyStatus.critical.color.toARGB32(),
      };
      expect(colors.length, 3);
    });
  });
}
