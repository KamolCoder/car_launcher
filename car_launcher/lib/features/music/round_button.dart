import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 96,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Theme.of(context).colorScheme.primary : AppColors.surfaceHigh,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: size * 0.55, color: filled ? Colors.black : Colors.white),
        ),
      ),
    );
  }
}
