import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alice.dart';
import '../../core/config.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/panel.dart';
import 'progress_bar.dart';
import 'round_button.dart';

class MusicPanel extends ConsumerWidget {
  const MusicPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStateProvider);
    return Panel(
      child: media.when(
        data: (state) => _MusicContent(state: state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка плеера: $e')),
      ),
    );
  }
}

const _swipeVelocity = 400.0;

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

void _onPlayPause(MediaState state) {
  if (state.hasSession) {
    NativeBridge.toggle();
  } else {
    NativeBridge.startYandex();
  }
}

/// Split screen: only the track title and full-size buttons.
class MusicSplitPanel extends ConsumerWidget {
  const MusicSplitPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaStateProvider);
    return Panel(
      child: media.when(
        data: (state) {
          final title = state.title ?? (state.hasSession ? '—' : 'Музыка не играет');
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onSwipe,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 32),
                MusicControls(state: state),
                const SizedBox(height: 32),
                Center(
                  child: FilledButton.tonalIcon(
                    onPressed: () => openAlice(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 72),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.mic_rounded, size: 36),
                    label: const Text('Алиса', style: TextStyle(fontSize: 26)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка плеера: $e')),
      ),
    );
  }
}

/// Prev / play-pause / next at full size (same in both layouts).
class MusicControls extends StatelessWidget {
  const MusicControls({super.key, required this.state});

  final MediaState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const RoundButton(icon: Icons.skip_previous_rounded, size: 96, onTap: NativeBridge.previous),
        RoundButton(
          icon: state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 128,
          filled: true,
          onTap: () => _onPlayPause(state),
        ),
        const RoundButton(icon: Icons.skip_next_rounded, size: 96, onTap: NativeBridge.next),
      ],
    );
  }
}

class _MusicContent extends StatelessWidget {
  const _MusicContent({required this.state});

  final MediaState state;

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
                    _onPlayPause(state);
                  },
                  child: _AlbumArt(art: state.art),
                ),
                const SizedBox(width: 28),
                Expanded(child: _TrackInfo(state: state)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ProgressBar(state: state),
        const SizedBox(height: 8),
        MusicControls(state: state),
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
  const _TrackInfo({required this.state});

  final MediaState state;

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
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1.15),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 28, color: AppColors.textSecondary),
        ),
        if (state.hasSession) ...[
          const SizedBox(height: 16),
          Text(
            AppConfig.appName(state.packageName),
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary),
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
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: accent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Нет доступа к уведомлениям — трек не отображается', style: TextStyle(fontSize: 18)),
          ),
          const TextButton(
            onPressed: NativeBridge.openNotificationAccessSettings,
            child: Text('Дать доступ', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
