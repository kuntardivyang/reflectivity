import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'oecf_calibrator.dart';

/// A rectangular region of interest in image coordinates (YUV Y-plane pixels).
class RoiBox {
  final int x;
  final int y;
  final int width;
  final int height;

  const RoiBox(this.x, this.y, this.width, this.height);
}

/// Extracts mean luminance from a bounding-box ROI inside a YUV420 camera frame.
///
/// The Y (luma) plane already encodes perceived brightness, so we only need
/// the Y bytes — no RGB conversion required. This keeps the hot path fast
/// enough for real-time processing.
class LuminanceAnalyzer {
  final OECFCalibrator calibrator;

  const LuminanceAnalyzer({required this.calibrator});

  /// Mean luminance (cd/m²) of the ROI in a YUV420 [frame].
  double meanLuminance(CameraImage frame, RoiBox roi) {
    final yPlane = frame.planes[0];
    final bytes = yPlane.bytes;
    final rowStride = yPlane.bytesPerRow;

    final samples = <int>[];
    final xEnd = (roi.x + roi.width).clamp(0, frame.width);
    final yEnd = (roi.y + roi.height).clamp(0, frame.height);

    for (int row = roi.y; row < yEnd; row++) {
      final rowStart = row * rowStride;
      for (int col = roi.x; col < xEnd; col++) {
        samples.add(bytes[rowStart + col]);
      }
    }

    if (samples.isEmpty) return 0;
    return calibrator.meanLuminance(samples);
  }

  /// Luminance delta (illuminated frame minus ambient frame) for the same ROI.
  ///
  /// A positive delta indicates light from the phone's LED flash being
  /// retroreflected back by the marking's glass beads.
  double luminanceDelta(
    CameraImage illuminated,
    CameraImage ambient,
    RoiBox roi,
  ) {
    final litL  = meanLuminance(illuminated, roi);
    final ambL  = meanLuminance(ambient, roi);
    return (litL - ambL).clamp(0.0, double.infinity).toDouble();
  }
}

/// Convenience extension for raw pixel sampling when you already have a
/// [Uint8List] of Y-plane bytes (e.g. from a decoded JPEG frame).
extension LuminanceFromBytes on LuminanceAnalyzer {
  double meanLuminanceFromBytes(
    Uint8List yBytes,
    int rowStride,
    RoiBox roi,
  ) {
    final samples = <int>[];
    final xEnd = roi.x + roi.width;
    final yEnd = roi.y + roi.height;
    for (int row = roi.y; row < yEnd; row++) {
      final rowStart = row * rowStride;
      for (int col = roi.x; col < xEnd; col++) {
        samples.add(yBytes[rowStart + col]);
      }
    }
    if (samples.isEmpty) return 0;
    return calibrator.meanLuminance(samples);
  }
}
