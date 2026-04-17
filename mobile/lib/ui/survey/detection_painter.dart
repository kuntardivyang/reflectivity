import 'package:flutter/material.dart';

import '../../core/ai/yolo_detector.dart';

/// Draws YOLO bounding boxes over the camera preview.
class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size frameSize;
  final Color color;

  DetectionPainter({
    required this.detections,
    required this.frameSize,
    this.color = const Color(0xFF22D3EE),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || frameSize.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final scaleX = size.width / frameSize.width;
    final scaleY = size.height / frameSize.height;

    for (final d in detections) {
      final rect = Rect.fromLTWH(
        d.box.x * scaleX,
        d.box.y * scaleY,
        d.box.width * scaleX,
        d.box.height * scaleY,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(DetectionPainter old) =>
      old.detections != detections || old.frameSize != frameSize;
}
