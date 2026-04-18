import 'dart:async';

import 'package:torch_light/torch_light.dart';

/// Strobes the phone's LED flash at a fixed frequency so that alternating
/// camera frames are captured with illumination (ON) and without (OFF).
///
/// The measurement pipeline pairs each ON frame with the subsequent OFF
/// frame to isolate the retroreflected component from ambient light.
class FlashController {
  final int hz;
  Timer? _timer;
  bool _isOn = false;
  bool _disposed = false;

  /// Events stream: `true` when the flash just turned ON, `false` when OFF.
  /// Consumers use this to tag camera frames as illuminated or ambient.
  final _stateController = StreamController<bool>.broadcast();
  Stream<bool> get state => _stateController.stream;

  bool get isOn => _isOn;

  FlashController({this.hz = 40});

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

    final halfPeriodMicros = (1000000 / (hz * 2)).round();
    _timer = Timer.periodic(
      Duration(microseconds: halfPeriodMicros),
      (_) => _toggle(),
    );
  }

  Future<void> _toggle() async {
    _isOn = !_isOn;
    try {
      if (_isOn) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      if (!_stateController.isClosed) {
        _stateController.add(_isOn);
      }
    } on Exception {
      _isOn = !_isOn;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_isOn) {
      try {
        await TorchLight.disableTorch();
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
