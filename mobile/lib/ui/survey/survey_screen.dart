import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/measurement/safety_classifier.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/permission_gate.dart';
import '../history/history_screen.dart';
import 'detection_painter.dart';
import 'survey_controller.dart';

class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  CameraController? _camera;
  bool _cameraReady = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final permissionError =
        await const PermissionGate().requestSurveyPermissions();
    if (permissionError != null) {
      if (mounted) setState(() => _initError = permissionError);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initError = 'No camera available on this device.');
        return;
      }
      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.startImageStream((frame) {
        ref.read(surveyControllerProvider.notifier).onFrame(frame);
      });
      if (!mounted) return;
      setState(() {
        _camera = controller;
        _cameraReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _initError = 'Camera init failed: $e');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(surveyControllerProvider);
    final detectorFallback = ref
        .watch(surveyControllerProvider.notifier)
        .detectorFallbackMode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_initError != null)
              _InitErrorView(message: _initError!)
            else if (_cameraReady && _camera != null)
              LayoutBuilder(
                builder: (context, cons) {
                  final preview = _camera!.value.previewSize;
                  final frameSize = preview != null
                      ? Size(preview.height, preview.width)
                      : Size(cons.maxWidth, cons.maxHeight);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_camera!),
                      CustomPaint(
                        painter: DetectionPainter(
                          detections: state.lastDetections,
                          frameSize: frameSize,
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              const Center(child: CircularProgressIndicator()),

            if (detectorFallback)
              const Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: _DemoModeBanner(),
              ),

            Positioned(
              top: detectorFallback ? 48 : 16,
              left: 16,
              right: 16,
              child: _StatusHud(state: state),
            ),

            Positioned(
              top: detectorFallback ? 48 : 16,
              right: 16,
              child: IconButton.filledTonal(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                icon: const Icon(Icons.history),
                tooltip: 'Session history',
              ),
            ),

            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _ControlBar(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.black87),
          SizedBox(width: 6),
          Text(
            'DEMO MODE — TFLite model missing, using fixed ROI',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitErrorView extends StatelessWidget {
  final String message;
  const _InitErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // Trigger a rebuild → parent reinvokes _initCamera on next frame.
                (context as Element).markNeedsBuild();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusHud extends StatelessWidget {
  final SurveyState state;
  const _StatusHud({required this.state});

  @override
  Widget build(BuildContext context) {
    final status = state.lastStatus;
    final color = status?.color ?? Colors.white54;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status?.label ?? 'WAITING',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Text(
                formatRl(state.lastRl),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill(
                icon: Icons.gps_fixed,
                label: state.lastSample == null
                    ? 'No GPS'
                    : formatLatLng(state.lastSample!.lat, state.lastSample!.lng),
                good: state.lastSample != null,
              ),
              const SizedBox(width: 8),
              _pill(
                icon: Icons.my_location,
                label: '${state.pointsCaptured} captured',
                good: true,
              ),
              const SizedBox(width: 8),
              _pill(
                icon: Icons.cloud_upload_outlined,
                label: '${state.pointsUploaded} sent',
                good: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String label, required bool good}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: good ? Colors.white12 : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ControlBar extends ConsumerWidget {
  final SurveyState state;
  const _ControlBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(surveyControllerProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.errorMessage != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(state.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          )
        else
          FilledButton.icon(
            onPressed: state.isRunning
                ? () => ctrl.stop()
                : () => ctrl.start(highway: 'NH-48'),
            style: FilledButton.styleFrom(
              backgroundColor: state.isRunning ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            ),
            icon: Icon(state.isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(
              state.isRunning ? 'STOP SURVEY' : 'START SURVEY',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
