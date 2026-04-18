import 'package:permission_handler/permission_handler.dart';

/// Requests runtime permissions required to run a survey.
///
/// Returns null on success, or a human-readable reason string on failure
/// so the UI can surface it without needing platform-specific logic.
class PermissionGate {
  const PermissionGate();

  Future<String?> requestSurveyPermissions() async {
    final results = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();

    final cam = results[Permission.camera];
    if (cam != PermissionStatus.granted) {
      return 'Camera permission is required to measure retroreflectivity.';
    }

    final loc = results[Permission.locationWhenInUse];
    if (loc != PermissionStatus.granted) {
      return 'Location permission is required to tag measurements.';
    }

    return null;
  }
}
