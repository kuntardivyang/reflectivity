import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/yolo_detector.dart';
import '../../core/camera/flash_controller.dart';
import '../../core/config.dart';
import '../../core/gps/location_service.dart';
import '../../core/measurement/luminance_analyzer.dart';
import '../../core/measurement/oecf_calibrator.dart';
import '../../core/measurement/rl_calculator.dart';
import '../../core/measurement/safety_classifier.dart';
import '../../data/local/database.dart';
import '../../data/models/measurement.dart';
import '../../data/models/survey_session.dart';
import '../../data/remote/api_client.dart';

/// Live snapshot of the survey shown in the UI overlay.
class SurveyState {
  final bool isRunning;
  final SurveySession? session;
  final double? lastRl;
  final SafetyStatus? lastStatus;
  final int pointsCaptured;
  final int pointsUploaded;
  final List<Detection> lastDetections;
  final GpsSample? lastSample;
  final String? errorMessage;

  const SurveyState({
    this.isRunning = false,
    this.session,
    this.lastRl,
    this.lastStatus,
    this.pointsCaptured = 0,
    this.pointsUploaded = 0,
    this.lastDetections = const [],
    this.lastSample,
    this.errorMessage,
  });

  SurveyState copyWith({
    bool? isRunning,
    SurveySession? session,
    double? lastRl,
    SafetyStatus? lastStatus,
    int? pointsCaptured,
    int? pointsUploaded,
    List<Detection>? lastDetections,
    GpsSample? lastSample,
    String? errorMessage,
    bool clearError = false,
  }) =>
      SurveyState(
        isRunning: isRunning ?? this.isRunning,
        session: session ?? this.session,
        lastRl: lastRl ?? this.lastRl,
        lastStatus: lastStatus ?? this.lastStatus,
        pointsCaptured: pointsCaptured ?? this.pointsCaptured,
        pointsUploaded: pointsUploaded ?? this.pointsUploaded,
        lastDetections: lastDetections ?? this.lastDetections,
        lastSample: lastSample ?? this.lastSample,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// Central coordinator. Orchestrates camera, flash, detector, GPS, DB, upload.
class SurveyController extends StateNotifier<SurveyState> {
  final YoloDetector _detector;
  final FlashController _flash;
  final LocationService _gps;
  final LuminanceAnalyzer _luminance;
  final RLCalculator _rl;
  final LocalDatabase _db;
  final ApiClient _api;

  CameraImage? _ambientFrame;
  bool _flashOn = false;
  StreamSubscription<bool>? _flashSub;
  Timer? _uploadTimer;

  SurveyController({
    required YoloDetector detector,
    required FlashController flash,
    required LocationService gps,
    required LuminanceAnalyzer luminance,
    required RLCalculator rl,
    required LocalDatabase db,
    required ApiClient api,
  })  : _detector = detector,
        _flash = flash,
        _gps = gps,
        _luminance = luminance,
        _rl = rl,
        _db = db,
        _api = api,
        super(const SurveyState());

  /// True once [start] has been called and the detector reported that the
  /// TFLite asset is missing. Used by the UI to show a DEMO MODE banner.
  bool get detectorFallbackMode => _detector.fallbackMode;

  /// Local DB accessor so other screens (e.g. history) can read sessions
  /// without constructing a second LocalDatabase instance.
  LocalDatabase get localDb => _db;

  Future<void> start({
    String? vehicleId,
    String? surveyor,
    String? highway,
  }) async {
    try {
      await _detector.load();
      await _gps.start();
      await _flash.start();

      final session = SurveySession(
        vehicleId: vehicleId,
        surveyor: surveyor,
        highway: highway,
        startedAt: DateTime.now().toUtc(),
      );
      await _db.insertSession(session);

      _flashSub = _flash.state.listen((isOn) => _flashOn = isOn);
      _uploadTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _drainUploadQueue(session.id),
      );

      state = state.copyWith(
        isRunning: true,
        session: session,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Process one camera frame. Called from the camera stream.
  Future<void> onFrame(CameraImage frame) async {
    if (!state.isRunning || state.session == null) return;

    if (!_flashOn) {
      _ambientFrame = frame;
      return;
    }
    final ambient = _ambientFrame;
    if (ambient == null) return;

    final detections = _detector.detect(frame);
    if (detections.isEmpty) {
      state = state.copyWith(lastDetections: const []);
      return;
    }

    final primary = detections.first;
    final delta = _luminance.luminanceDelta(frame, ambient, primary.box);
    final rlValue = _rl.compute(delta);
    final status = SafetyClassifier.classify(rlValue);
    final sample = _gps.lastSample;

    state = state.copyWith(
      lastRl: rlValue,
      lastStatus: status,
      lastDetections: detections,
      lastSample: sample,
    );

    if (sample != null) {
      final m = Measurement(
        sessionId: state.session!.id,
        highway: state.session!.highway,
        lat: sample.lat,
        lng: sample.lng,
        rlValue: rlValue,
        status: status.label,
        speedKmh: sample.speedKmh,
        capturedAt: DateTime.now().toUtc(),
      );
      await _db.insertMeasurement(m);
      state = state.copyWith(pointsCaptured: state.pointsCaptured + 1);
    }
  }

  Future<void> stop() async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    await _flashSub?.cancel();
    _flashSub = null;
    await _flash.stop();
    await _gps.stop();

    if (state.session != null) {
      final ended = state.session!.copyWith(
        endedAt: DateTime.now().toUtc(),
        totalPoints: state.pointsCaptured,
      );
      await _db.updateSession(ended);
      await _drainUploadQueue(ended.id);
      state = state.copyWith(isRunning: false, session: ended);
    } else {
      state = state.copyWith(isRunning: false);
    }
  }

  Future<void> _drainUploadQueue(String sessionId) async {
    final pending = await _db.pendingUploads(limit: AppConfig.uploadBatchSize);
    if (pending.isEmpty) return;
    final result = await _api.uploadBatchWithRetry(
      sessionId: sessionId,
      measurements: pending,
    );
    if (result != null) {
      await _db.markUploaded(pending.map((m) => m.id).toList());
      state = state.copyWith(
        pointsUploaded: state.pointsUploaded + result.accepted,
      );
    }
  }
}

final surveyControllerProvider =
    StateNotifierProvider<SurveyController, SurveyState>((ref) {
  final calibrator = OECFCalibrator.defaultCurve();
  return SurveyController(
    detector: YoloDetector(),
    flash: FlashController(hz: AppConfig.flashHz),
    gps: LocationService(),
    luminance: LuminanceAnalyzer(calibrator: calibrator),
    rl: const RLCalculator(),
    db: LocalDatabase(),
    api: ApiClient(),
  );
});
