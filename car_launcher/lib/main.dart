import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ProviderScope(child: CarLauncherApp()));
}

class CarLauncherApp extends ConsumerWidget {
  const CarLauncherApp({super.key});

  /// Night: black layer over the whole UI (dims white text and accent alike, no glare).
  static const _nightDim = Color(0x4D000000); // 30% black

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(uiSettingsProvider).accent.color;
    final dimmed = ref.watch(dimmedProvider);

    return MaterialApp(
      title: 'Car Launcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(accent),
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          if (child != null) child,
          if (dimmed) const IgnorePointer(child: ColoredBox(color: _nightDim)),
        ],
      ),
      home: const HomeScreen(),
    );
  }
}
