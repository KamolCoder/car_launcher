import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/theme.dart';

class Dock extends StatelessWidget {
  const Dock({super.key, required this.onSettings});

  final VoidCallback onSettings;

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
    final items = <_DockItem>[
      _DockItem(Icons.navigation_rounded, 'Навигатор',
          () => _launch(context, AppConfig.yandexNavigator, 'Яндекс Навигатор')),
      _DockItem(Icons.map_rounded, 'Карты',
          () => _launch(context, AppConfig.yandexMaps, 'Яндекс Карты')),
      _DockItem(Icons.music_note_rounded, 'Музыка',
          () => _launch(context, AppConfig.yandexMusic, 'Яндекс Музыка')),
      _DockItem(Icons.phone_rounded, 'Телефон', NativeBridge.openDialer),
      _DockItem(Icons.settings_rounded, 'Настройки', onSettings),
    ];

    return SizedBox(
      height: 112,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _DockButton(item: items[i])),
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
  const _DockButton({required this.item});

  final _DockItem item;

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
            Icon(item.icon, size: 44),
            const SizedBox(height: 6),
            Text(item.label, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
