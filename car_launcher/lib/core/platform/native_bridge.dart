import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Snapshot of the active media session (Yandex Music or any other player).
class MediaState {
  const MediaState({
    required this.hasAccess,
    required this.packageName,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.positionMs,
    required this.playing,
    required this.speed,
    required this.art,
    required this.receivedAt,
  });

  final bool hasAccess;
  final String? packageName;
  final String? title;
  final String? artist;
  final int durationMs;
  final int positionMs;
  final bool playing;
  final double speed;
  final Uint8List? art;
  final DateTime receivedAt;

  bool get hasSession => packageName != null;

  /// position = positionMs + (now - receivedAt) * speed, clamped to duration.
  int currentPositionMs(DateTime now) {
    if (!playing) return positionMs;
    final elapsed = now.difference(receivedAt).inMilliseconds;
    final position = positionMs + (elapsed * speed).round();
    return durationMs > 0 ? position.clamp(0, durationMs) : position;
  }
}

/// Platform channels to the Kotlin side (MainActivity.kt).
class NativeBridge {
  NativeBridge._();

  static const _media = MethodChannel('car_launcher/media');
  static const _mediaState = EventChannel('car_launcher/media_state');
  static const _system = MethodChannel('car_launcher/system');
  static const _ignition = EventChannel('car_launcher/ignition');

  // Media commands
  static Future<void> play() => _media.invokeMethod('play');
  static Future<void> pause() => _media.invokeMethod('pause');
  static Future<void> toggle() => _media.invokeMethod('toggle');
  static Future<void> next() => _media.invokeMethod('next');
  static Future<void> previous() => _media.invokeMethod('previous');
  static Future<void> startYandex() => _media.invokeMethod('startYandex');
  static Future<void> seekTo(int positionMs) =>
      _media.invokeMethod('seekTo', {'positionMs': positionMs});

  /// Album art is sent only when the track changes, so the last one is cached here.
  static Stream<MediaState> mediaStates() {
    Uint8List? lastArt;
    return _mediaState.receiveBroadcastStream().map((event) {
      final m = Map<Object?, Object?>.from(event as Map);
      if (m['artChanged'] == true) lastArt = m['art'] as Uint8List?;
      return MediaState(
        hasAccess: m['hasAccess'] as bool? ?? false,
        packageName: m['package'] as String?,
        title: m['title'] as String?,
        artist: m['artist'] as String?,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        positionMs: (m['positionMs'] as num?)?.toInt() ?? 0,
        playing: m['playing'] as bool? ?? false,
        speed: (m['speed'] as num?)?.toDouble() ?? 1.0,
        art: lastArt,
        receivedAt: DateTime.now(),
      );
    });
  }

  static Stream<bool> ignition() =>
      _ignition.receiveBroadcastStream().map((e) => e as bool);

  // System
  static Future<bool> hasNotificationAccess() => _bool('hasNotificationAccess');
  static Future<bool> hasOverlayPermission() => _bool('hasOverlayPermission');
  static Future<bool> isDefaultLauncher() => _bool('isDefaultLauncher');
  static Future<bool> isIgnoringBatteryOptimizations() =>
      _bool('isIgnoringBatteryOptimizations');

  static Future<void> openNotificationAccessSettings() =>
      _system.invokeMethod('openNotificationAccessSettings');
  static Future<void> openOverlaySettings() =>
      _system.invokeMethod('openOverlaySettings');
  static Future<void> openHomeSettings() => _system.invokeMethod('openHomeSettings');
  static Future<void> openAppSettings() => _system.invokeMethod('openAppSettings');

  static Future<bool> openDialer() => _bool('openDialer');
  static Future<bool> launchApp(String packageName) async =>
      await _system.invokeMethod<bool>('launchApp', {'package': packageName}) ?? false;

  static Future<bool> _bool(String method) async =>
      await _system.invokeMethod<bool>(method) ?? false;
}
