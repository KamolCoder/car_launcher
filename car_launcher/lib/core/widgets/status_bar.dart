import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/native_bridge.dart';
import '../providers.dart';
import '../theme.dart';

const _tabular = [FontFeature.tabularFigures()];
const _iconSize = 32.0;
const _fontSize = 26.0;

/// Own status bar (system bar is hidden): ignition, cellular, Wi-Fi, battery.
/// Large and color-coded to be readable at a glance while driving.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  static T _value<T>(AsyncValue<T> v, T fallback) =>
      v.when(data: (d) => d, loading: () => fallback, error: (_, __) => fallback);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final car = _value(ref.watch(carStatusProvider), CarStatus.unknown);
    final signal = _value(ref.watch(signalProvider), SignalStatus.none);
    final hotspot = _value(ref.watch(hotspotSsidProvider), null);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Ignition(on: car.ignitionOn),
        if (signal.cellLevel >= 0) ...[
          const SizedBox(width: 24),
          _Cellular(level: signal.cellLevel, type: signal.cellType),
        ],
        if (hotspot != null) ...[
          const SizedBox(width: 24),
          _Iphone(connected: signal.wifiSsid == hotspot),
        ],
        if (signal.wifiLevel >= 0) ...[
          const SizedBox(width: 24),
          _Wifi(level: signal.wifiLevel),
        ],
        if (car.batteryLevel >= 0) ...[
          const SizedBox(width: 24),
          _Battery(level: car.batteryLevel, charging: car.charging),
        ],
      ],
    );
  }
}

/// 3-4 bars white, 2 yellow, 0-1 red.
Color _signalColor(int level) {
  if (level >= 3) return Colors.white;
  if (level == 2) return AppColors.accent;
  return AppColors.error;
}

class _Ignition extends StatelessWidget {
  const _Ignition({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.ok : AppColors.textSecondary;
    return Icon(on ? Icons.bolt_rounded : Icons.local_parking_rounded, color: color, size: _iconSize);
  }
}

class _Cellular extends StatelessWidget {
  const _Cellular({required this.level, required this.type});

  final int level;
  final String? type;

  @override
  Widget build(BuildContext context) {
    final color = _signalColor(level);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (type != null) ...[
          Text(type!, style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w700, color: color, height: 1)),
          const SizedBox(width: 6),
        ],
        _Bars(level: level, color: color),
      ],
    );
  }
}

/// 4 ascending bars, [level] of them filled.
class _Bars extends StatelessWidget {
  const _Bars({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _iconSize - 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 6,
              height: (_iconSize - 4) * (i + 1) / 4,
              decoration: BoxDecoration(
                color: i < level ? color : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// iPhone hotspot: green when the tablet is on it, red (tap -> Wi-Fi panel) when not.
class _Iphone extends StatelessWidget {
  const _Iphone({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      connected ? Icons.phone_iphone_rounded : Icons.phonelink_off_rounded,
      color: connected ? AppColors.ok : AppColors.error,
      size: _iconSize,
    );
    if (connected) return icon;
    return GestureDetector(onTap: NativeBridge.openWifiPanel, child: icon);
  }
}

class _Wifi extends StatelessWidget {
  const _Wifi({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final icon = switch (level) {
      >= 3 => Icons.wifi_rounded,
      2 => Icons.wifi_2_bar_rounded,
      1 => Icons.wifi_1_bar_rounded,
      _ => Icons.signal_wifi_0_bar_rounded,
    };
    return Icon(icon, color: _signalColor(level), size: _iconSize);
  }
}

class _Battery extends StatelessWidget {
  const _Battery({required this.level, required this.charging});

  final int level;
  final bool charging;

  /// Charging green; otherwise >=50 green, 20-49 yellow, <20 red.
  Color get _color {
    if (charging || level >= 50) return AppColors.ok;
    if (level >= 20) return AppColors.accent;
    return AppColors.error;
  }

  IconData get _icon {
    if (charging) return Icons.battery_charging_full_rounded;
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 75) return Icons.battery_6_bar_rounded;
    if (level >= 60) return Icons.battery_5_bar_rounded;
    if (level >= 45) return Icons.battery_4_bar_rounded;
    if (level >= 30) return Icons.battery_3_bar_rounded;
    if (level >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, color: color, size: _iconSize),
        const SizedBox(width: 2),
        Text(
          '$level%',
          style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w700, color: color, fontFeatures: _tabular),
        ),
      ],
    );
  }
}
