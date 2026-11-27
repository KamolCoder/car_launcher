import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'platform/native_bridge.dart';

final mediaStateProvider = StreamProvider<MediaState>((ref) => NativeBridge.mediaStates());

final ignitionProvider = StreamProvider<bool>((ref) => NativeBridge.ignition());

/// Speed in km/h: m/s * 3.6. Below 0.5 m/s (~1.8 km/h) treated as 0 (GPS noise).
/// Emits null when location permission is not granted.
final speedProvider = StreamProvider<double?>((ref) async* {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    yield null;
    return;
  }

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    ),
  ).map((p) => p.speed < 0.5 ? 0.0 : p.speed * 3.6);
});
