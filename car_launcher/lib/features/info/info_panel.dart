import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/panel.dart';

const _tabular = [FontFeature.tabularFigures()];

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: Panel(child: ClockWidget())),
        SizedBox(height: 20),
        Expanded(
          child: Panel(
            child: Stack(
              children: [
                Center(child: SpeedWidget()),
                Positioned(top: 0, right: 0, child: IgnitionIndicator()),
              ],
            ),
          ),
        ),
      ],
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

class IgnitionIndicator extends ConsumerWidget {
  const IgnitionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(ignitionProvider).when(
          data: (v) => v,
          loading: () => false,
          error: (_, __) => false,
        );
    final color = on ? AppColors.ok : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(on ? Icons.bolt_rounded : Icons.local_parking_rounded, color: color, size: 24),
        const SizedBox(width: 6),
        Text(on ? 'Зажигание' : 'Парковка', style: TextStyle(fontSize: 18, color: color)),
      ],
    );
  }
}
