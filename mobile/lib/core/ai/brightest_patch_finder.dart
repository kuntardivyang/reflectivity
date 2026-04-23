import 'package:camera/camera.dart';

import '../measurement/luminance_analyzer.dart';

/// Finds the brightest rectangular patch in the lower half of a camera frame.
///
/// Why this works without ML:
/// Retroreflective road markings reflect 100x - 1000x more light back to
/// the source than surrounding asphalt under directional illumination.
/// During the flash-ON frame, the marking is therefore almost certainly
/// the brightest patch visible on the road surface.
///
/// The lower half is scanned because the road ahead of the vehicle
/// occupies the bottom 2/3 of a dashboard-mounted camera view. Sampling
/// the sky or horizon would pick up the sun / streetlights, not paint.
class BrightestPatchFinder {
  /// Number of horizontal cells scanned.
  final int gridCols;

  /// Number of vertical cells scanned inside the search band.
  final int gridRows;

  /// Fraction of the frame height where scanning begins.
  /// 0.65 keeps the search band in the lower third of the frame so
  /// upright pedestrians and oncoming headlights — bright but not
  /// markings — fall outside the candidate region.
  final double topFraction;

  /// Fraction of the frame height where scanning ends (below bumper).
  final double bottomFraction;

  /// Patch width as a fraction of frame width. Markings are linear and
  /// horizontal in dashboard view, so the patch is wider than tall.
  /// A wider/shorter shape down-weights vertical bright objects (people,
  /// poles) and up-weights horizontal stripes (lane lines, zebras).
  final double patchWidthFraction;

  /// Patch height as a fraction of frame height.
  final double patchHeightFraction;

  const BrightestPatchFinder({
    this.gridCols = 5,
    this.gridRows = 3,
    this.topFraction = 0.65,
    this.bottomFraction = 0.95,
    this.patchWidthFraction = 0.32,
    this.patchHeightFraction = 0.10,
  });

  /// Return the ROI with the highest mean Y-plane luminance within the
  /// configured search band. Falls back to the center-bottom of the
  /// frame if the Y plane is empty.
  RoiBox findBrightest(CameraImage frame, LuminanceAnalyzer analyzer) {
    final fw = frame.width;
    final fh = frame.height;
    final patchW = (fw * patchWidthFraction).round().clamp(1, fw);
    final patchH = (fh * patchHeightFraction).round().clamp(1, fh);

    final topY = (fh * topFraction).round();
    final bottomY = (fh * bottomFraction).round() - patchH;
    if (bottomY <= topY) {
      return RoiBox((fw - patchW) ~/ 2, (fh - patchH) ~/ 2, patchW, patchH);
    }

    const leftX = 0;
    final rightX = fw - patchW;

    RoiBox best = RoiBox((fw - patchW) ~/ 2, topY, patchW, patchH);
    double bestLum = -1;

    for (int r = 0; r < gridRows; r++) {
      final y = topY + ((bottomY - topY) * r ~/ (gridRows - 1).clamp(1, 99));
      for (int c = 0; c < gridCols; c++) {
        final x = leftX + ((rightX - leftX) * c ~/ (gridCols - 1).clamp(1, 99));
        final box = RoiBox(x, y, patchW, patchH);
        final pixels = analyzer.samplePixels(frame, box);
        if (pixels.isEmpty) continue;

        // Reject patches dominated by clipped (saturated) pixels.
        // Streetlights, headlights, and the sun produce Y=255 across
        // most of the patch; a road marking under flash is bright but
        // rarely fully clipped. Using > 30 % saturated as the cut-off
        // keeps real markings while throwing away light sources.
        int saturated = 0;
        for (final p in pixels) {
          if (p >= 250) saturated++;
        }
        if (saturated > pixels.length * 0.3) continue;

        final lum = analyzer.calibrator.meanLuminance(pixels);
        if (lum > bestLum) {
          bestLum = lum;
          best = box;
        }
      }
    }
    return best;
  }
}
