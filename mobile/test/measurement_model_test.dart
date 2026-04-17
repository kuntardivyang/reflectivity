import 'package:flutter_test/flutter_test.dart';
import 'package:reflectscan/data/models/measurement.dart';
import 'package:reflectscan/data/models/survey_session.dart';

void main() {
  group('Measurement', () {
    test('assigns a UUID when none provided', () {
      final m = Measurement(
        sessionId: 'session-a',
        lat: 28.6139,
        lng: 77.2090,
        rlValue: 87.3,
        status: 'WARNING',
        capturedAt: DateTime.utc(2026, 4, 17, 10, 30),
      );
      expect(m.id, isNotEmpty);
      expect(m.id.length, greaterThanOrEqualTo(32));
    });

    test('round-trips through toMap/fromMap', () {
      final original = Measurement(
        id: 'test-id-1',
        sessionId: 'sess-1',
        highway: 'NH-48',
        lat: 28.6,
        lng: 77.2,
        rlValue: 87.3,
        status: 'WARNING',
        speedKmh: 72.4,
        capturedAt: DateTime.utc(2026, 4, 17, 10, 30),
        uploaded: true,
      );
      final clone = Measurement.fromMap(original.toMap());

      expect(clone.id, original.id);
      expect(clone.sessionId, original.sessionId);
      expect(clone.highway, original.highway);
      expect(clone.lat, original.lat);
      expect(clone.lng, original.lng);
      expect(clone.rlValue, original.rlValue);
      expect(clone.status, original.status);
      expect(clone.speedKmh, original.speedKmh);
      expect(clone.capturedAt, original.capturedAt);
      expect(clone.uploaded, original.uploaded);
    });

    test('toApiPayload matches backend schema keys', () {
      final m = Measurement(
        sessionId: 'sess-1',
        highway: 'NH-48',
        lat: 28.6,
        lng: 77.2,
        rlValue: 87.3,
        status: 'WARNING',
        speedKmh: 72.4,
        capturedAt: DateTime.utc(2026, 4, 17, 10, 30),
      );
      final payload = m.toApiPayload();

      expect(payload.keys, containsAll(
        ['lat', 'lng', 'rl_value', 'status', 'speed_kmh', 'highway', 'captured_at'],
      ));
      expect(payload['lat'], 28.6);
      expect(payload['rl_value'], 87.3);
      expect(payload['captured_at'], '2026-04-17T10:30:00.000Z');
    });
  });

  group('SurveySession', () {
    test('copyWith updates only the provided fields', () {
      final s = SurveySession(
        id: 'sess-1',
        vehicleId: 'NHAI-042',
        highway: 'NH-48',
        startedAt: DateTime.utc(2026, 4, 17, 10),
      );
      final updated = s.copyWith(totalPoints: 123);

      expect(updated.id, s.id);
      expect(updated.vehicleId, s.vehicleId);
      expect(updated.totalPoints, 123);
      expect(updated.endedAt, isNull);
    });

    test('round-trips through toMap/fromMap', () {
      final original = SurveySession(
        id: 'sess-1',
        vehicleId: 'NHAI-042',
        surveyor: 'Demo',
        highway: 'NH-48',
        startedAt: DateTime.utc(2026, 4, 17, 10),
        endedAt: DateTime.utc(2026, 4, 17, 12),
        totalPoints: 500,
      );
      final clone = SurveySession.fromMap(original.toMap());
      expect(clone.id, original.id);
      expect(clone.totalPoints, original.totalPoints);
      expect(clone.endedAt, original.endedAt);
    });
  });
}
