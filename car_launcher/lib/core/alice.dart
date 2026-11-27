import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform/native_bridge.dart';

/// Opens Alice AI in voice mode; if not installed, Play Store opens + snackbar.
Future<void> openAlice(BuildContext context) async {
  HapticFeedback.mediumImpact();
  final ok = await NativeBridge.openAlice();
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Установите «Алиса AI» из Play Маркета', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
