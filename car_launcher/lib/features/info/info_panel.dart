import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/panel.dart';

const _tabular = [FontFeature.tabularFigures()];

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, this.horizontal = false});

  /// Split screen: clock and speed side by side instead of stacked.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    const clock = Expanded(child: Panel(child: ClockWidget()));
    const speed = Expanded(
      child: Panel(
        child: Stack(
          children: [
            Center(child: SpeedWidget()),
            Positioned(top: 0, right: 0, child: StatusIndicators()),
          ],
        ),
      ),
    );

    return horizontal
        ? const Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [clock, SizedBox(width: 16), speed],
          )
        : const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [clock, SizedBox(height: 20), speed],
          );
  }
}

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  static const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  static const _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  /// Tick exactly on the second boundary.
  void _scheduleTick() {
    final now = DateTime.now();
    _timer = Timer(Duration(milliseconds: 1000 - now.millisecond), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_two(_now.hour)}:${_two(_now.minute)}',
            style: const TextStyle(fontSize: 104, fontWeight: FontWeight.w700, fontFeatures: _tabular),
          ),
          Text(
            '${_weekdays[_now.weekday - 1]}, ${_now.day} ${_months[_now.month - 1]}',
            style: const TextStyle(fontSize: 26, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class SpeedWidget extends ConsumerWidget {
  const SpeedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(speedProvider).when(
          data: (kmh) => kmh == null ? '—' : kmh.round().toString(),
          loading: () => '—',
          error: (_, __) => '—',
        );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w700, height: 1, fontFeatures: _tabular),
          ),
          const SizedBox(height: 8),
          const Text('км/ч', style: TextStyle(fontSize: 28, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Ignition state + battery percent (top-right corner of the speed panel).
class StatusIndicators extends ConsumerWidget {
  const StatusIndicators({super.key});

  static const _lowBattery = 20;

  static IconData _batteryIcon(int level, bool charging) {
    if (charging) return Icons.battery_charging_full_rounded;
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 75) return Icons.battery_6_bar_rounded;
    if (level >= 60) return Icons.battery_5_bar_rounded;
    if (level >= 45) return Icons.battery_4_bar_rounded;
    if (level >= 30) return Icons.battery_3_bar_rounded;
    if (level >= _lowBattery) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(carStatusProvider).when(
          data: (v) => v,
          loading: () => CarStatus.unknown,
          error: (_, __) => CarStatus.unknown,
        );
    final on = status.ignitionOn;
    final ignitionColor = on ? AppColors.ok : AppColors.textSecondary;

    final level = status.batteryLevel;
    final batteryColor = level >= 0 && level < _lowBattery && !status.charging
        ? AppColors.error
        : (status.charging ? AppColors.ok : AppColors.textSecondary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(on ? Icons.bolt_rounded : Icons.local_parking_rounded, color: ignitionColor, size: 24),
        const SizedBox(width: 6),
        Text(on ? 'Зажигание' : 'Парковка', style: TextStyle(fontSize: 18, color: ignitionColor)),
        if (level >= 0) ...[
          const SizedBox(width: 16),
          Icon(_batteryIcon(level, status.charging), color: batteryColor, size: 24),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: TextStyle(fontSize: 18, color: batteryColor, fontFeatures: _tabular),
          ),
        ],
      ],
    );
  }
}
