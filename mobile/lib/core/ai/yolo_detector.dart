import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../measurement/luminance_analyzer.dart';

/// One detection from the YOLOv8 model.
class Detection {
  final RoiBox box;
  final double confidence;
  final int classId;

  const Detection({
    required this.box,
    required this.confidence,
    required this.classId,
  });
}

/// TFLite wrapper for YOLOv8n road-marking detection.
///
/// Expects `assets/models/yolov8n.tflite` with input shape [1, 640, 640, 3]
/// (float16 or float32) and standard YOLOv8 output layout.
class YoloDetector {
  static const int inputSize = 640;
  static const int numClasses = 2;   // lane marking, solid edge line
  static const double confThreshold = 0.35;
  static const double iouThreshold = 0.45;

  Interpreter? _interpreter;
  bool _loaded = false;
  bool _fallbackMode = false;

  /// True when the model failed to load and [detect] is returning a
  /// fixed center ROI instead of running inference. Lets the UI show a
  /// "MODEL MISSING" banner while the rest of the pipeline still works.
  bool get fallbackMode => _fallbackMode;

  Future<void> load({String assetPath = 'assets/models/yolov8n.tflite'}) async {
    if (_loaded) return;
    try {
      _interpreter = await Interpreter.fromAsset(assetPath);
      _loaded = true;
    } catch (_) {
      _loaded = true;
      _fallbackMode = true;
    }
  }

  /// Run inference on a YUV420 camera frame. Returns surviving detections.
  List<Detection> detect(CameraImage frame) {
    if (!_loaded) return const [];
    if (_fallbackMode || _interpreter == null) {
      final w = frame.width.toDouble();
      final h = frame.height.toDouble();
      return [
        Detection(
          box: RoiBox(w * 0.35, h * 0.55, w * 0.30, h * 0.30),
          confidence: 0.5,
          classId: 0,
        ),
      ];
    }

    final input = _preprocess(frame);
    final output = List.filled(1 * (4 + numClasses) * 8400, 0.0)
        .reshape([1, 4 + numClasses, 8400]);
    _interpreter!.run(input, output);
    return _postprocess(output, frame.width, frame.height);
  }

  // ─── preprocess ──────────────────────────────────────────────────

  List<List<List<List<double>>>> _preprocess(CameraImage frame) {
    final rgb = _yuvToRgb(frame);
    final resized = img.copyResize(rgb, width: inputSize, height: inputSize);
    final tensor = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          },
        ),
      ),
    );
    return tensor;
  }

  img.Image _yuvToRgb(CameraImage frame) {
    final w = frame.width, h = frame.height;
    final out = img.Image(width: w, height: h);
    final y = frame.planes[0].bytes;
    final u = frame.planes[1].bytes;
    final v = frame.planes[2].bytes;
    final uvRowStride = frame.planes[1].bytesPerRow;
    final uvPixelStride = frame.planes[1].bytesPerPixel ?? 2;

    for (int row = 0; row < h; row++) {
      for (int col = 0; col < w; col++) {
        final yIdx = row * frame.planes[0].bytesPerRow + col;
        final uvIdx = (row >> 1) * uvRowStride + (col >> 1) * uvPixelStride;
        final Y = y[yIdx];
        final U = u[uvIdx] - 128;
        final V = v[uvIdx] - 128;
        int r = (Y + 1.402 * V).round().clamp(0, 255);
        int g = (Y - 0.344 * U - 0.714 * V).round().clamp(0, 255);
        int b = (Y + 1.772 * U).round().clamp(0, 255);
        out.setPixelRgb(col, row, r, g, b);
      }
    }
    return out;
  }

  // ─── postprocess ─────────────────────────────────────────────────

  List<Detection> _postprocess(
    List<dynamic> output,
    int frameW,
    int frameH,
  ) {
    final candidates = <Detection>[];
    final data = output[0] as List;  // shape [4 + numClasses, 8400]

    for (int i = 0; i < 8400; i++) {
      double maxConf = 0;
      int maxCls = 0;
      for (int c = 0; c < numClasses; c++) {
        final conf = (data[4 + c][i] as num).toDouble();
        if (conf > maxConf) {
          maxConf = conf;
          maxCls = c;
        }
      }
      if (maxConf < confThreshold) continue;

      final cx = (data[0][i] as num).toDouble();
      final cy = (data[1][i] as num).toDouble();
      final w  = (data[2][i] as num).toDouble();
      final h  = (data[3][i] as num).toDouble();

      final scaleX = frameW / inputSize;
      final scaleY = frameH / inputSize;
      final x = ((cx - w / 2) * scaleX).round();
      final y = ((cy - h / 2) * scaleY).round();
      final bw = (w * scaleX).round();
      final bh = (h * scaleY).round();

      candidates.add(Detection(
        box: RoiBox(x, y, bw, bh),
        confidence: maxConf,
        classId: maxCls,
      ));
    }

    return _nms(candidates);
  }

  List<Detection> _nms(List<Detection> candidates) {
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <Detection>[];
    for (final det in candidates) {
      bool overlap = false;
      for (final k in kept) {
        if (_iou(det.box, k.box) > iouThreshold) {
          overlap = true;
          break;
        }
      }
      if (!overlap) kept.add(det);
    }
    return kept;
  }

  double _iou(RoiBox a, RoiBox b) {
    final x1 = math.max(a.x, b.x);
    final y1 = math.max(a.y, b.y);
    final x2 = math.min(a.x + a.width, b.x + b.width);
    final y2 = math.min(a.y + a.height, b.y + b.height);
    final inter = math.max(0, x2 - x1) * math.max(0, y2 - y1);
    final union = a.width * a.height + b.width * b.height - inter;
    return union == 0 ? 0 : inter / union;
  }

  void dispose() {
    if (_loaded) _interpreter?.close();
  }
}
