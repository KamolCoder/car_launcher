import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets/panel.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupStatus {
  const _SetupStatus({
    required this.notifications,
    required this.overlay,
    required this.location,
    required this.defaultLauncher,
    required this.battery,
    required this.lockAdmin,
    required this.phone,
  });

  final bool notifications;
  final bool overlay;
  final bool location;
  final bool defaultLauncher;
  final bool battery;
  final bool lockAdmin;
  final bool phone;
}

class _SetupScreenState extends ConsumerState<SetupScreen> with WidgetsBindingObserver {
  _SetupStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // User returns from system settings -> re-check
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final r = await Future.wait([
      NativeBridge.hasNotificationAccess(),
      NativeBridge.hasOverlayPermission(),
      _hasLocation(),
      NativeBridge.isDefaultLauncher(),
      NativeBridge.isIgnoringBatteryOptimizations(),
      NativeBridge.isLockAdmin(),
      NativeBridge.hasPhonePermission(),
    ]);
    if (!mounted) return;
    setState(() => _status = _SetupStatus(
          notifications: r[0],
          overlay: r[1],
          location: r[2],
          defaultLauncher: r[3],
          battery: r[4],
          lockAdmin: r[5],
          phone: r[6],
        ));
  }

  static Future<bool> _hasLocation() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<void> _fixLocation() async {
    final p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) await Geolocator.openAppSettings();
    ref.invalidate(speedProvider);
    await _refresh();
  }

  Future<void> _fixPhone() async {
    await NativeBridge.requestPhonePermission();
    // Result arrives asynchronously; the permission dialog pauses the app -> resumed -> _refresh()
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Text('Настройки', style: TextStyle(fontSize: 30)),
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _AppearanceSetup(),
                _SetupTile(
                  title: 'Доступ к уведомлениям',
                  subtitle: 'Трек, обложка и управление Яндекс Музыкой',
                  ok: s.notifications,
                  onFix: NativeBridge.openNotificationAccessSettings,
                ),
                _SetupTile(
                  title: 'Поверх других приложений',
                  subtitle: 'Автозапуск лаунчера и музыки при включении зажигания',
                  ok: s.overlay,
                  onFix: NativeBridge.openOverlaySettings,
                ),
                _SetupTile(
                  title: 'Геолокация',
                  subtitle: 'Скорость по GPS',
                  ok: s.location,
                  onFix: _fixLocation,
                ),
                _SetupTile(
                  title: 'Лаунчер по умолчанию',
                  subtitle: 'Кнопка «Домой» и загрузка планшета открывают Car Launcher',
                  ok: s.defaultLauncher,
                  onFix: NativeBridge.openHomeSettings,
                ),
                _SetupTile(
                  title: 'Батарея: без ограничений',
                  subtitle: 'Иначе Samsung может выгрузить фоновый сервис. Батарея → «Не ограничено»',
                  ok: s.battery,
                  onFix: NativeBridge.openAppSettings,
                ),
                _SetupTile(
                  title: 'Блокировка экрана',
                  subtitle: 'Планшет блокируется сразу после выключения зажигания (администратор устройства)',
                  ok: s.lockAdmin,
                  onFix: NativeBridge.requestLockAdmin,
                ),
                _SetupTile(
                  title: 'Тип сети',
                  subtitle: 'Подпись LTE / 5G в строке статуса (полоски сигнала работают и без этого)',
                  ok: s.phone,
                  onFix: _fixPhone,
                ),
                const _HotspotSetup(),
                const _AliceSetup(),
                const SizedBox(height: 12),
                const Panel(
                  child: Text(
                    'Также в настройках Android:\n'
                    '• Экран блокировки → «Нет» или «Провести» (иначе экран не разблокируется сам)\n'
                    '• Тайм-аут экрана → 30 сек–1 мин (запасной вариант, если блокировка не включена)',
                    style: TextStyle(fontSize: 20, height: 1.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.onFix,
  });

  final String title;
  final String subtitle;
  final bool ok;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? AppColors.ok : AppColors.error,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (!ok)
              FilledButton(
                onPressed: onFix,
                style: FilledButton.styleFrom(minimumSize: const Size(180, 64)),
                child: const Text('Настроить', style: TextStyle(fontSize: 22)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Alice by voice ("Слушай, Алиса") is configured in the Yandex app, not here.
class _AliceSetup extends StatelessWidget {
  const _AliceSetup();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.mic_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Алиса', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    '1. Установить «Алиса AI» из Play Маркета\n'
                    '2. Ассистент по умолчанию → «Алиса AI» (кнопка справа)\n'
                    '3. Алиса AI → Настройки → Голосовая активация → вкл. («Слушай, Алиса»)\n'
                    '4. Батарея → «Никогда не спящие» → добавить Алиса AI',
                    style: TextStyle(fontSize: 18, height: 1.4, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: NativeBridge.openAssistantSettings,
              style: FilledButton.styleFrom(minimumSize: const Size(180, 64)),
              child: const Text('Настроить', style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}

/// iPhone hotspot name + password -> WifiNetworkSuggestion (auto-join when the iPhone broadcasts).
class _HotspotSetup extends ConsumerWidget {
  const _HotspotSetup();

  Future<void> _edit(BuildContext context, WidgetRef ref, String? current) async {
    final ssid = TextEditingController(text: current ?? '');
    final password = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Модем iPhone', style: TextStyle(fontSize: 26)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssid,
                style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'Имя сети (iPhone → Настройки → Основные → Об этом устройстве → Имя)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(labelText: 'Пароль режима модема'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(fontSize: 20)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final error = await NativeBridge.saveHotspot(ssid.text, password.text);
    ref.invalidate(hotspotSsidProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Сохранено. Если Android спросит «Разрешить предлагаемые сети?» — разрешите',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssid = ref.watch(hotspotSsidProvider).when(
          data: (v) => v,
          loading: () => null,
          error: (_, __) => null,
        );
    final ok = ssid != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              ok ? Icons.phone_iphone_rounded : Icons.error_rounded,
              color: ok ? AppColors.ok : AppColors.error,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ok ? 'Модем iPhone: $ssid' : 'Модем iPhone',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Планшет сам подключается, как только iPhone включает режим модема. '
                    'Значок 📱 в строке статуса: зелёный — подключён, красный — нажмите, чтобы открыть Wi-Fi',
                    style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _edit(context, ref, ssid),
              style: FilledButton.styleFrom(minimumSize: const Size(180, 64)),
              child: Text(ok ? 'Изменить' : 'Настроить', style: const TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accent color (match the car's interior lighting) and night dimming.
class _AppearanceSetup extends ConsumerWidget {
  const _AppearanceSetup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(uiSettingsProvider);
    final notifier = ref.read(uiSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Цвет подсветки', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final accent in AccentChoice.values)
                  _ColorChip(
                    accent: accent,
                    selected: accent == settings.accent,
                    onTap: () => notifier.setAccent(accent),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Ночной режим (приглушить экран)', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SegmentedButton<NightMode>(
              segments: [
                for (final mode in NightMode.values)
                  ButtonSegment(
                    value: mode,
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(mode.label, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
              selected: {settings.nightMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => notifier.setNightMode(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.accent, required this.selected, required this.onTap});

  final AccentChoice accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: selected ? accent.color : Colors.transparent, width: 3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 18, backgroundColor: accent.color),
            const SizedBox(width: 12),
            Text(accent.label, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
