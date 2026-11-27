import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../dock/dock.dart';
import '../info/info_panel.dart';
import '../music/music_panel.dart';
import '../setup/setup_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  /// Below this width (dp) the split-screen layout is used.
  static const _compactWidth = 900.0;

  bool _setupOk = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _checkSetup();
    }
  }

  Future<void> _checkSetup() async {
    final results = await Future.wait([
      NativeBridge.hasNotificationAccess(),
      NativeBridge.hasOverlayPermission(),
    ]);
    if (mounted) setState(() => _setupOk = results.every((ok) => ok));
  }

  Future<void> _openSetup() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen()));
    await _checkSetup();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(isDashboardProvider).when(
          data: (v) => v,
          loading: () => false,
          error: (_, __) => false,
        );

    // Launcher: back button must not close it
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < _compactWidth;
              final gap = compact ? 16.0 : 20.0;
              return Padding(
                padding: EdgeInsets.all(gap),
                child: Column(
                  children: [
                    if (!_setupOk) ...[
                      _SetupBanner(onTap: _openSetup),
                      const SizedBox(height: 16),
                    ],
                    Expanded(child: compact ? _compactBody(gap) : _wideBody(gap)),
                    SizedBox(height: gap),
                    Dock(onSettings: _openSetup, compact: compact, dashboard: dashboard),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Full screen: music left, clock + speed right.
  Widget _wideBody(double gap) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(flex: 3, child: MusicPanel()),
          SizedBox(width: gap),
          const Expanded(flex: 2, child: InfoPanel()),
        ],
      );

  /// Split screen: music on top, clock + speed in one row below.
  Widget _compactBody(double gap) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(flex: 3, child: MusicPanel(compact: true)),
          SizedBox(height: gap),
          const Expanded(flex: 2, child: InfoPanel(horizontal: true)),
        ],
      );
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.black, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Не все разрешения выданы — автозапуск и управление музыкой могут не работать',
                  style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.black, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}
