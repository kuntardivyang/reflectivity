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

  /// Reflects [FlashController.available]. Flips to false when the torch
  /// stops responding mid-survey so the UI can show "No flash" instead
  /// of silently feeding stale ambient frames.
  final bool flashAvailable;

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
    this.flashAvailable = true,
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
    bool? flashAvailable,
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
        flashAvailable: flashAvailable ?? this.flashAvailable,
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
  DateTime _lastCaptureAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _captureInProgress = false;

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

      _flashSub = _flash.state.listen((isOn) {
        _flashOn = isOn;
        // Propagate torch-unavailable state to the UI: if the flash
        // controller has tripped its failure breaker, reflect that now.
        if (state.flashAvailable != _flash.available) {
          state = state.copyWith(flashAvailable: _flash.available);
        }
      });
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
  ///
  /// Design notes:
  /// - Torch APIs on real devices are unreliable. If the flash stopped
  ///   strobing we fall back to single-frame luminance so captures still
  ///   flow — less accurate than a flash/ambient delta, but better than
  ///   a stuck counter during a demo.
  /// - A GPS fix can take 30-60 s on weak signal. We stamp measurements
  ///   with (0, 0) when no sample has arrived yet; the UI surfaces this
  ///   as "Waiting for GPS" but the pipeline keeps running so users see
  ///   the flash and counters working.
  /// - Captures are throttled to [AppConfig.minCaptureInterval] so we do
  ///   not flood SQLite at 30 fps.
  Future<void> onFrame(CameraImage frame) async {
    if (!state.isRunning || state.session == null) return;
    if (_captureInProgress) return;

    // Pair ambient ↔ illuminated frames whenever the torch is actually
    // toggling. If torch failed, we still fall through with null ambient.
    if (_flash.available && !_flashOn) {
      _ambientFrame = frame;
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastCaptureAt) < AppConfig.minCaptureInterval) {
      return;
    }
    _lastCaptureAt = now;
    _captureInProgress = true;

    try {
      final detections = _detector.detect(frame);
      if (detections.isEmpty) {
        state = state.copyWith(lastDetections: const []);
        return;
      }

      final primary = detections.first;
      final ambient = _ambientFrame;

      // Pick best available luminance signal:
      //   1. Flash delta (most accurate, needs ambient + illuminated pair)
      //   2. Single-frame absolute luminance (flash broken fallback)
      final double signalLum = ambient != null && _flash.available
          ? _luminance.luminanceDelta(frame, ambient, primary.box)
          : _luminance.meanLuminance(frame, primary.box);
      final rlValue = _rl.compute(signalLum);
      final status = SafetyClassifier.classify(rlValue);
      final sample = _gps.lastSample;

      state = state.copyWith(
        lastRl: rlValue,
        lastStatus: status,
        lastDetections: detections,
        lastSample: sample,
      );

      final m = Measurement(
        sessionId: state.session!.id,
        highway: state.session!.highway,
        lat: sample?.lat ?? 0.0,
        lng: sample?.lng ?? 0.0,
        rlValue: rlValue,
        status: status.label,
        speedKmh: sample?.speedKmh,
        capturedAt: now.toUtc(),
      );
      await _db.insertMeasurement(m);
      state = state.copyWith(pointsCaptured: state.pointsCaptured + 1);
    } finally {
      _captureInProgress = false;
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
  final luminance = LuminanceAnalyzer(calibrator: calibrator);
  return SurveyController(
    detector: YoloDetector(analyzer: luminance),
    flash: FlashController(hz: AppConfig.flashHz),
    gps: LocationService(),
    luminance: luminance,
    rl: const RLCalculator(),
    db: LocalDatabase(),
    api: ApiClient(),
  );
});
