import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/theme.dart';

class Dock extends StatelessWidget {
  const Dock({super.key, required this.onSettings, this.compact = false, this.dashboard = false});

  final VoidCallback onSettings;

  /// Narrow layout (split screen).
  final bool compact;

  /// Running in DashboardActivity: show "full screen" instead of apps that would cover it.
  final bool dashboard;

  Future<void> _openNavigator(BuildContext context) async {
    final ok = await NativeBridge.openSplit(AppConfig.yandexNavigator);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Яндекс Навигатор не установлено', style: TextStyle(fontSize: 20))),
      );
    }
  }

  Future<void> _launch(BuildContext context, String packageName, String label) async {
    final ok = await NativeBridge.launchApp(packageName);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label не установлено', style: const TextStyle(fontSize: 20))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = _DockItem(Icons.navigation_rounded, 'Навигатор', () => _openNavigator(context));
    final settings = _DockItem(Icons.settings_rounded, 'Настройки', onSettings);

    final items = dashboard
        ? <_DockItem>[
            navigator,
            _DockItem(Icons.phone_rounded, 'Телефон', NativeBridge.openDialer),
            _DockItem(Icons.fullscreen_rounded, 'Полный экран', NativeBridge.exitSplit),
            settings,
          ]
        : <_DockItem>[
      navigator,
      _DockItem(Icons.map_rounded, 'Карты',
          () => _launch(context, AppConfig.yandexMaps, 'Яндекс Карты')),
      _DockItem(Icons.music_note_rounded, 'Музыка',
          () => _launch(context, AppConfig.yandexMusic, 'Яндекс Музыка')),
      _DockItem(Icons.phone_rounded, 'Телефон', NativeBridge.openDialer),
      settings,
    ];

    return SizedBox(
      height: compact ? 88 : 112,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _DockButton(item: items[i], compact: compact)),
          ],
        ],
      ),
    );
  }
}

class _DockItem {
  const _DockItem(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.item, required this.compact});

  final _DockItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: compact ? 36 : 44),
            SizedBox(height: compact ? 4 : 6),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 16 : 20),
            ),
          ],
        ),
      ),
    );
  }
}
