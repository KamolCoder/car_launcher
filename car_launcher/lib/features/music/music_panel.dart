import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/panel.dart';
import 'progress_bar.dart';
import 'round_button.dart';

class MusicPanel extends ConsumerWidget {
  const MusicPanel({super.key, this.compact = false});

  /// Split screen: smaller buttons and fonts.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStateProvider);
    return Panel(
      child: media.when(
        data: (state) => _MusicContent(state: state, compact: compact),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка плеера: $e')),
      ),
    );
  }
}

class _MusicContent extends StatelessWidget {
  const _MusicContent({required this.state, required this.compact});

  final MediaState state;
  final bool compact;

  static const _swipeVelocity = 400.0;

  void _onSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -_swipeVelocity) {
      HapticFeedback.lightImpact();
      NativeBridge.next();
    } else if (v > _swipeVelocity) {
      HapticFeedback.lightImpact();
      NativeBridge.previous();
    }
  }

  void _onPlayPause() {
    if (state.hasSession) {
      NativeBridge.toggle();
    } else {
      NativeBridge.startYandex();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!state.hasAccess) ...[
          const _AccessHint(),
          const SizedBox(height: 16),
        ],
        // Swipe zone: art + track info (not the slider, to avoid gesture conflicts)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onSwipe,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _onPlayPause();
                  },
                  child: _AlbumArt(art: state.art),
                ),
                SizedBox(width: compact ? 20 : 28),
                Expanded(child: _TrackInfo(state: state, compact: compact)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ProgressBar(state: state),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RoundButton(
              icon: Icons.skip_previous_rounded,
              size: compact ? 80 : 96,
              onTap: NativeBridge.previous,
            ),
            RoundButton(
              icon: state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: compact ? 104 : 128,
              filled: true,
              onTap: _onPlayPause,
            ),
            RoundButton(
              icon: Icons.skip_next_rounded,
              size: compact ? 80 : 96,
              onTap: NativeBridge.next,
            ),
          ],
        ),
      ],
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.art});

  final Uint8List? art;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: art != null
            ? Image.memory(art!, fit: BoxFit.cover, gaplessPlayback: true)
            : const ColoredBox(
                color: AppColors.surfaceHigh,
                child: Center(
                  child: Icon(Icons.music_note_rounded, size: 96, color: AppColors.textSecondary),
                ),
              ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.state, required this.compact});

  final MediaState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = state.title ?? (state.hasSession ? '—' : 'Музыка не играет');
    final subtitle = state.artist ?? (state.hasSession ? '' : 'Нажмите ▶ — запустится Яндекс Музыка');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: compact ? 30 : 40, fontWeight: FontWeight.w700, height: 1.15),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: compact ? 22 : 28, color: AppColors.textSecondary),
        ),
        if (state.hasSession) ...[
          const SizedBox(height: 16),
          Text(
            AppConfig.appName(state.packageName),
            style: const TextStyle(fontSize: 18, color: AppColors.accent),
          ),
        ],
      ],
    );
  }
}

class _AccessHint extends StatelessWidget {
  const _AccessHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.accent),
          SizedBox(width: 12),
          Expanded(
            child: Text('Нет доступа к уведомлениям — трек не отображается', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: NativeBridge.openNotificationAccessSettings,
            child: Text('Дать доступ', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
