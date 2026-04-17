import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../models/measurement.dart';

class UploadResult {
  final int accepted;
  final int segmentsCreated;
  final int alertsCreated;

  const UploadResult({
    required this.accepted,
    required this.segmentsCreated,
    required this.alertsCreated,
  });

  factory UploadResult.fromJson(Map<String, dynamic> j) => UploadResult(
        accepted: j['accepted'] as int,
        segmentsCreated: j['segments_created'] as int? ?? 0,
        alertsCreated: j['alerts_created'] as int? ?? 0,
      );
}

class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
            ));

  /// Upload a batch of measurements. Returns the server's acceptance report.
  Future<UploadResult> uploadBatch({
    required String sessionId,
    required List<Measurement> measurements,
  }) async {
    if (measurements.isEmpty) {
      return const UploadResult(accepted: 0, segmentsCreated: 0, alertsCreated: 0);
    }

    final payload = {
      'session_id': sessionId,
      'measurements': measurements.map((m) => m.toApiPayload()).toList(),
    };

    final response = await _dio.post('/api/measurements', data: payload);
    return UploadResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Upload with exponential-backoff retry. Returns null if all retries fail.
  Future<UploadResult?> uploadBatchWithRetry({
    required String sessionId,
    required List<Measurement> measurements,
    int maxAttempts = 3,
  }) async {
    Duration delay = AppConfig.uploadRetryDelay;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await uploadBatch(
          sessionId: sessionId,
          measurements: measurements,
        );
      } on DioException catch (e) {
        if (attempt == maxAttempts) return null;
        if (e.response?.statusCode == 400) return null; // bad payload, no point retrying
        await Future.delayed(delay);
        delay *= 2;
      } catch (_) {
        if (attempt == maxAttempts) return null;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    return null;
  }

  Future<bool> pingHealth() async {
    try {
      final r = await _dio.get('/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
