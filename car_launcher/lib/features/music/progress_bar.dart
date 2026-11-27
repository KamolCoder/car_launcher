import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/theme.dart';

class ProgressBar extends StatefulWidget {
  const ProgressBar({super.key, required this.state});

  final MediaState state;

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  Timer? _ticker;
  Timer? _dragReset;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (widget.state.playing && _dragValue == null) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fresh state from the player -> drop the local drag value
    if (!identical(oldWidget.state, widget.state)) _dragValue = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dragReset?.cancel();
    super.dispose();
  }

  void _onSeekEnd(double value) {
    NativeBridge.seekTo(value.round());
    // Some players don't emit a new state after seek -> unfreeze anyway
    _dragReset?.cancel();
    _dragReset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _dragValue = null);
    });
  }

  static String _format(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.state.durationMs;
    final hasDuration = duration > 0;
    final max = hasDuration ? duration.toDouble() : 1.0;
    final position = widget.state.currentPositionMs(DateTime.now()).toDouble();
    final value = hasDuration ? (_dragValue ?? position).clamp(0.0, max) : 0.0;

    const timeStyle = TextStyle(
      fontSize: 22,
      color: AppColors.textSecondary,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Row(
      children: [
        SizedBox(width: 76, child: Text(_format(value.round()), style: timeStyle)),
        Expanded(
          child: Slider(
            value: value,
            max: max,
            onChanged: hasDuration ? (v) => setState(() => _dragValue = v) : null,
            onChangeEnd: hasDuration ? _onSeekEnd : null,
          ),
        ),
        SizedBox(
          width: 76,
          child: Text(_format(duration), style: timeStyle, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
