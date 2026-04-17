import 'package:uuid/uuid.dart';

class Measurement {
  final String id;
  final String sessionId;
  final String? highway;
  final double lat;
  final double lng;
  final double rlValue;
  final String status;        // SAFE | WARNING | CRITICAL
  final double? speedKmh;
  final DateTime capturedAt;
  final bool uploaded;

  Measurement({
    String? id,
    required this.sessionId,
    this.highway,
    required this.lat,
    required this.lng,
    required this.rlValue,
    required this.status,
    this.speedKmh,
    required this.capturedAt,
    this.uploaded = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'highway': highway,
        'lat': lat,
        'lng': lng,
        'rl_value': rlValue,
        'status': status,
        'speed_kmh': speedKmh,
        'captured_at': capturedAt.toIso8601String(),
        'uploaded': uploaded ? 1 : 0,
      };

  factory Measurement.fromMap(Map<String, dynamic> m) => Measurement(
        id: m['id'] as String,
        sessionId: m['session_id'] as String,
        highway: m['highway'] as String?,
        lat: m['lat'] as double,
        lng: m['lng'] as double,
        rlValue: m['rl_value'] as double,
        status: m['status'] as String,
        speedKmh: m['speed_kmh'] as double?,
        capturedAt: DateTime.parse(m['captured_at'] as String),
        uploaded: (m['uploaded'] as int) == 1,
      );

  /// JSON payload for the backend API.
  Map<String, dynamic> toApiPayload() => {
        'lat': lat,
        'lng': lng,
        'rl_value': rlValue,
        'status': status,
        'speed_kmh': speedKmh,
        'highway': highway,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      };
}
