import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform/native_bridge.dart';

/// Accent colors to match the car's interior lighting (Spark M300: cyan).
enum AccentChoice {
  cyan('Циан', Color(0xFF00E5FF)),
  turquoise('Бирюзовый', Color(0xFF19D3DA)),
  blue('Синий', Color(0xFF2F80FF)),
  green('Зелёный', Color(0xFF30D158)),
  white('Белый', Color(0xFFFFFFFF));

  const AccentChoice(this.label, this.color);

  final String label;
  final Color color;
}

enum NightMode {
  auto('Авто (19:00–07:00)'),
  on('Всегда'),
  off('Выкл');

  const NightMode(this.label);

  final String label;
}

class UiSettings {
  const UiSettings({required this.accent, required this.nightMode});

  static const defaults = UiSettings(accent: AccentChoice.cyan, nightMode: NightMode.auto);

  final AccentChoice accent;
  final NightMode nightMode;

  UiSettings copyWith({AccentChoice? accent, NightMode? nightMode}) =>
      UiSettings(accent: accent ?? this.accent, nightMode: nightMode ?? this.nightMode);
}

/// Persisted in Android SharedPreferences ("ui") via the system channel.
class UiSettingsNotifier extends Notifier<UiSettings> {
  static const _accentKey = 'accent';
  static const _nightKey = 'night_mode';

  @override
  UiSettings build() {
    unawaited(_load());
    return UiSettings.defaults;
  }

  Future<void> _load() async {
    final accent = await NativeBridge.getPref(_accentKey);
    final night = await NativeBridge.getPref(_nightKey);
    state = UiSettings(
      accent: AccentChoice.values.firstWhere((a) => a.name == accent, orElse: () => AccentChoice.cyan),
      nightMode: NightMode.values.firstWhere((n) => n.name == night, orElse: () => NightMode.auto),
    );
  }

  Future<void> setAccent(AccentChoice accent) async {
    state = state.copyWith(accent: accent);
    await NativeBridge.setPref(_accentKey, accent.name);
  }

  Future<void> setNightMode(NightMode mode) async {
    state = state.copyWith(nightMode: mode);
    await NativeBridge.setPref(_nightKey, mode.name);
  }
}

final uiSettingsProvider = NotifierProvider<UiSettingsNotifier, UiSettings>(UiSettingsNotifier.new);

/// Night = 19:00..07:00 local time; re-checked every minute.
final isNightTimeProvider = StreamProvider<bool>((ref) async* {
  bool night() {
    final h = DateTime.now().hour;
    return h >= 19 || h < 7;
  }

  yield night();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => night()).distinct();
});

/// Whether the screen should be dimmed right now.
final dimmedProvider = Provider<bool>((ref) {
  final mode = ref.watch(uiSettingsProvider).nightMode;
  return switch (mode) {
    NightMode.on => true,
    NightMode.off => false,
    NightMode.auto => ref.watch(isNightTimeProvider).when(
          data: (v) => v,
          loading: () => false,
          error: (_, __) => false,
        ),
  };
});
