import 'dart:async';

import 'package:torch_light/torch_light.dart';

/// Strobes the phone's LED flash at a fixed frequency so that alternating
/// camera frames are captured with illumination (ON) and without (OFF).
///
/// The measurement pipeline pairs each ON frame with the subsequent OFF
/// frame to isolate the retroreflected component from ambient light.
/// A hardware-level torch toggler. Returning a future that completes
/// means the state change landed. Throw on failure so the controller
/// can count errors and trip its breaker.
typedef TorchToggler = Future<void> Function(bool on);

class FlashController {
  final int hz;
  Timer? _timer;
  bool _isOn = false;
  bool _disposed = false;
  bool _toggleInFlight = false;
  int _consecutiveFailures = 0;

  /// External torch toggler, typically wired to
  /// CameraController.setFlashMode() so the torch shares the camera's
  /// active hardware session. When null, we fall back to the torch_light
  /// plugin which talks directly to the platform torch API — on many
  /// Android devices this conflicts with an active image stream and
  /// trips the failure breaker within seconds.
  TorchToggler? _toggler;

  /// Replace the toggler at runtime — the UI calls this once the
  /// CameraController has finished initialising.
  set toggler(TorchToggler? fn) => _toggler = fn;

  /// Threshold after which we assume the torch API is broken on this
  /// device/permission combo. When reached, [available] flips to false and
  /// the survey controller falls back to single-frame luminance.
  static const int _maxConsecutiveFailures = 3;
  bool _available = true;
  bool get available => _available;

  /// Events stream: `true` when the flash just turned ON, `false` when OFF.
  /// Consumers use this to tag camera frames as illuminated or ambient.
  final _stateController = StreamController<bool>.broadcast();
  Stream<bool> get state => _stateController.stream;

  bool get isOn => _isOn;

  FlashController({this.hz = 2});

  Future<bool> isAvailable() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Begin strobing. Toggles twice per period so both ON and OFF phases fire.
  Future<void> start() async {
    if (_disposed || _timer != null) return;
    _available = true;
    _consecutiveFailures = 0;

    final halfPeriodMicros = (1000000 / (hz * 2)).round();
    _timer = Timer.periodic(
      Duration(microseconds: halfPeriodMicros),
      (_) => _toggle(),
    );
  }

  /// Toggle torch state. Torch APIs are not reentrant — if a previous call
  /// is still awaited, skip this tick rather than queuing another request
  /// that would eventually time out and kill the LED.
  Future<void> _toggle() async {
    if (_toggleInFlight || !_available) return;
    _toggleInFlight = true;
    final target = !_isOn;
    try {
      final override = _toggler;
      if (override != null) {
        await override(target);
      } else if (target) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      _isOn = target;
      _consecutiveFailures = 0;
      if (!_stateController.isClosed) {
        _stateController.add(_isOn);
      }
    } catch (_) {
      _consecutiveFailures += 1;
      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        _available = false;
        _timer?.cancel();
        _timer = null;
        if (!_stateController.isClosed) {
          _stateController.add(false);
        }
      }
    } finally {
      _toggleInFlight = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_isOn) {
      try {
        final override = _toggler;
        if (override != null) {
          await override(false);
        } else {
          await TorchLight.disableTorch();
        }
      } catch (_) {}
      _isOn = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _stateController.close();
  }
}
