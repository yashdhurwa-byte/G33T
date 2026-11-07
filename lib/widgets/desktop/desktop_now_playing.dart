import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/controllers/player_metadata_controller.dart';
import 'package:mornye/l10n/l10n.dart';
import 'package:mornye/providers/lyrics_translation_provider.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/theme/player_artwork_theme.dart';
import 'package:mornye/utils/playback_seek_preview.dart';
import 'package:mornye/widgets/desktop/desktop_inspector.dart';
import 'package:mornye/widgets/desktop/desktop_window.dart';
import 'package:mornye/widgets/desktop/dopamine_desktop_player.dart';

/// Now Playing covers the desktop window in full-screen desktop mode:
/// featuring the spinning vinyl platter, real-time lyrics ticker, live hardware DAC telemetry HUD,
/// and full playback controls adapted to both Theme Engines.
class DesktopNowPlaying extends ConsumerStatefulWidget {
  const DesktopNowPlaying({super.key, this.metadataControllerFactory});

  final PlayerMetadataController Function()? metadataControllerFactory;

  @override
  ConsumerState<DesktopNowPlaying> createState() => _DesktopNowPlayingState();
}

class _DesktopNowPlayingState extends ConsumerState<DesktopNowPlaying> {
  late final _metadata =
      widget.metadataControllerFactory?.call() ?? PlayerMetadataController();
  final _seekPreview = PlaybackSeekPreview();
  ProviderSubscription<AsyncValue<MediaItem?>>? _mediaItemSub;
  late final LyricsTranslationController _lyricsTranslation;

  @override
  void initState() {
    super.initState();
    _lyricsTranslation = ref.read(lyricsTranslationProvider.notifier);
    _mediaItemSub = ref.listenManual<AsyncValue<MediaItem?>>(
      currentMediaItemProvider,
      (previous, next) {
        if (previous?.value?.id != next.value?.id) _seekPreview.reset();
        if (previous?.value?.id == next.value?.id && previous != null) return;
        unawaited(
          _metadata.load(next.value, inspectUnresolvedContentUri: true),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _mediaItemSub?.close();
    _lyricsTranslation.cancel(owner: this);
    _metadata.dispose();
    _seekPreview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    if (context.isMornye) return _buildPlayer(context, mediaItem);
    return PlayerArtworkTheme(
      artUri: mediaItem?.artUri?.toString(),
      child: Builder(builder: (context) => _buildPlayer(context, mediaItem)),
    );
  }

  Widget _buildPlayer(BuildContext context, MediaItem? mediaItem) {
    final mornye = context.isMornye;
    final theme = mornye
        ? MornyeTheme.fromContext(context, brightness: Brightness.dark)
        : Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Theme(
      data: theme,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: desktopWindowFullScreen,
              builder: (context, fullScreen, _) => mediaItem == null
                  ? Center(
                      child: Text(
                        context.l10n.nowPlayingNothingPlaying,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : DopamineDesktopPlayer(
                      mediaItem: mediaItem,
                      metadata: _metadata,
                      seekPreview: _seekPreview,
                      onClose: closeDesktopNowPlaying,
                      onToggleFullScreen: () {
                        desktopWindowFullScreen.value = !desktopWindowFullScreen.value;
                      },
                      isFullScreen: fullScreen,
                    ),
            ),
            // The player covers the title bar row, so it drags the window on desktop.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: desktopTitleBarHeight,
              child: DesktopWindowDragArea(zoomOnDoubleClick: true),
            ),
          ],
        ),
      ),
    );
  }
}
