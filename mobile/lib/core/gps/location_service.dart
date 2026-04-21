import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// A GPS sample at a point in time.
class GpsSample {
  final double lat;
  final double lng;
  final double? altitude;
  final double speedKmh;
  final DateTime timestamp;
  final double accuracyMeters;

  const GpsSample({
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.speedKmh,
    required this.timestamp,
    required this.accuracyMeters,
  });

  factory GpsSample.fromPosition(Position p) => GpsSample(
        lat: p.latitude,
        lng: p.longitude,
        altitude: p.altitude,
        speedKmh: p.speed * 3.6,            // m/s → km/h
        timestamp: p.timestamp,
        accuracyMeters: p.accuracy,
      );
}

class LocationService {
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<GpsSample>.broadcast();

  /// Broadcast stream of GPS samples. Begins emitting once [start] is called.
  Stream<GpsSample> get stream => _controller.stream;

  GpsSample? _last;
  GpsSample? get lastSample => _last;

  /// Request permission and begin emitting samples at ≥1 Hz.
  Future<void> start() async {
    if (_sub != null) return;

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw StateError('Location services disabled on device');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    // Kick off a one-shot fix in parallel with the stream. The stream
    // can stall for 30-60 s waiting for a "best" fix on weak signal;
    // getCurrentPosition returns whatever the OS has cached or can
    // acquire quickly so the UI gets a point to show fast.
    unawaited(
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).then((p) {
        final sample = GpsSample.fromPosition(p);
        _last = sample;
        if (!_controller.isClosed) _controller.add(sample);
      }).catchError((_) {}),
    );

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        // "high" emits on cell+wifi+GPS hybrid; "best" demands GNSS-grade
        // and stays silent on cloudy/indoor starts, which is why users
        // saw "No GPS" forever in early testing.
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((p) {
      final sample = GpsSample.fromPosition(p);
      _last = sample;
      _controller.add(sample);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
