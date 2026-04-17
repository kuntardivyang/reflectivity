import 'package:uuid/uuid.dart';

class SurveySession {
  final String id;
  final String? vehicleId;
  final String? surveyor;
  final String? highway;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int totalPoints;

  SurveySession({
    String? id,
    this.vehicleId,
    this.surveyor,
    this.highway,
    required this.startedAt,
    this.endedAt,
    this.totalPoints = 0,
  }) : id = id ?? const Uuid().v4();

  SurveySession copyWith({DateTime? endedAt, int? totalPoints}) =>
      SurveySession(
        id: id,
        vehicleId: vehicleId,
        surveyor: surveyor,
        highway: highway,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        totalPoints: totalPoints ?? this.totalPoints,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'surveyor': surveyor,
        'highway': highway,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'total_points': totalPoints,
      };

  factory SurveySession.fromMap(Map<String, dynamic> m) => SurveySession(
        id: m['id'] as String,
        vehicleId: m['vehicle_id'] as String?,
        surveyor: m['surveyor'] as String?,
        highway: m['highway'] as String?,
        startedAt: DateTime.parse(m['started_at'] as String),
        endedAt: m['ended_at'] != null
            ? DateTime.parse(m['ended_at'] as String)
            : null,
        totalPoints: m['total_points'] as int? ?? 0,
      );
}
