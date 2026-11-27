import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform/native_bridge.dart';

/// Opens Alice; snackbar if no Yandex app with Alice is installed.
Future<void> openAlice(BuildContext context) async {
  HapticFeedback.mediumImpact();
  final ok = await NativeBridge.openAlice();
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Установите «Яндекс с Алисой» из Play Маркета', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
