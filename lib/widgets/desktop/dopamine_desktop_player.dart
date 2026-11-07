import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mornye/controllers/clickable_metadata.dart' show pushPage;
import 'package:mornye/controllers/player_metadata_controller.dart';
import 'package:mornye/controllers/player_track_navigation.dart';
import 'package:mornye/l10n/l10n.dart';
import 'package:mornye/providers/library_collections_provider.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/screens/equalizer_screen.dart';
import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/utils/lyrics_parser.dart';
import 'package:mornye/utils/playback_seek_preview.dart';
import 'package:mornye/widgets/audio_output_button.dart';
import 'package:mornye/widgets/audio_signal_telemetry_hud.dart';
import 'package:mornye/widgets/desktop/desktop_inspector.dart';
import 'package:mornye/widgets/lyrics_options_button.dart';
import 'package:mornye/widgets/mornye_context_menu.dart';
import 'package:mornye/widgets/mornye_player_background.dart';
import 'package:mornye/widgets/material_player_backdrop.dart';
import 'package:mornye/widgets/mornye_player_favorite_button.dart';
import 'package:mornye/widgets/mornye_player_queue.dart';
import 'package:mornye/widgets/no_scrollbars.dart';
import 'package:mornye/widgets/player_details_sheet.dart';
import 'package:mornye/widgets/player_lyrics_section.dart';
import 'package:mornye/widgets/player_playback_controls.dart';
import 'package:mornye/widgets/player_volume_control.dart';
import 'package:mornye/widgets/playlist_picker_sheet.dart';
import 'package:mornye/widgets/turntable_platter.dart';

enum DopamineDesktopPanel { lyrics, queue }

/// Immersive Full-Screen Landscape Desktop Mode Player View inspired by Dopamine.
///
/// Features:
/// - Large spinning vinyl platter with continuous unidirectional rotation and gesture scratching
/// - Centered live hardware audio & DAC signal telemetry HUD pill
/// - Full real-time synchronized lyrics ticker with active line highlighting and seeking
/// - Complete dual theme engine synchronization:
///   * Engine A (Mornye): #000000 AMOLED black, #8B5CF6 electric violet, #FFFFFF stark white
///   * Engine B (Material): #FFFFFF background, #FCE4EC Sakura pink panels/pills, #6A1B9A Deep Royal Purple
/// - Seamless orientation and tablet/desktop form factor adaptation
class DopamineDesktopPlayer extends ConsumerStatefulWidget {
  const DopamineDesktopPlayer({
    super.key,
    required this.mediaItem,
    required this.metadata,
    required this.seekPreview,
    this.onClose,
    this.onToggleFullScreen,
    this.isFullScreen = false,
  });

  final MediaItem mediaItem;
  final PlayerMetadataController metadata;
  final PlaybackSeekPreview seekPreview;
  final VoidCallback? onClose;
  final VoidCallback? onToggleFullScreen;
  final bool isFullScreen;

  @override
  ConsumerState<DopamineDesktopPlayer> createState() => _DopamineDesktopPlayerState();
}

class _DopamineDesktopPlayerState extends ConsumerState<DopamineDesktopPlayer> {
  DopamineDesktopPanel _currentPanel = DopamineDesktopPanel.lyrics;

  void _shareLyrics(LyricLine? line) {
    if (!mounted) return;
    unawaited(
      SharePlus.instance.share(
        ShareParams(text: line?.text ?? widget.metadata.lyrics.plainText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mornye = context.isMornye;
    final theme = mornye
        ? MornyeTheme.fromContext(context, brightness: Brightness.dark)
        : Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Theme Engine Colors
    // Engine A: AMOLED black (#000000), electric violet (#8B5CF6), stark white (#FFFFFF)
    // Engine B: Pure white (#FFFFFF), Sakura pink (#FCE4EC), Deep Royal Purple (#6A1B9A)
    final bgColor = mornye ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final primaryAccent = mornye ? const Color(0xFF8B5CF6) : const Color(0xFF6A1B9A);
    final panelBg = mornye
        ? const Color(0xFF0C0C0F).withValues(alpha: 0.88)
        : const Color(0xFFFCE4EC).withValues(alpha: 0.85);
    final panelBorder = mornye
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.20)
        : const Color(0xFF6A1B9A).withValues(alpha: 0.20);
    final titleColor = mornye ? Colors.white : const Color(0xFF1D1B20);
    final subtitleColor = mornye ? const Color(0xFFA1A1AA) : const Color(0xFF6A1B9A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background ambient layer
          if (mornye)
            MornyePlayerBackground(artUri: widget.mediaItem.artUri)
          else
            MaterialPlayerBackdrop(
              mediaItem: widget.mediaItem,
              colorScheme: colorScheme,
              showArtwork: false,
            ),

          // Main Layout
          SafeArea(
            child: Column(
              children: [
                // 1. Dopamine Header Bar
                _buildHeaderBar(
                  context,
                  mornye: mornye,
                  primaryAccent: primaryAccent,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                ),

                // 2. Main Two-Pane Dopamine Body
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 700;
                      if (!isWide) {
                        return _buildNarrowFallback(
                          context,
                          constraints,
                          mornye,
                          colorScheme,
                          primaryAccent,
                          titleColor,
                          subtitleColor,
                          panelBg,
                          panelBorder,
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Pane: Vinyl Platter, Telemetry HUD, Metadata & Controls
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
                              child: _buildLeftConsole(
                                context,
                                constraints,
                                mornye: mornye,
                                colorScheme: colorScheme,
                                primaryAccent: primaryAccent,
                                titleColor: titleColor,
                                subtitleColor: subtitleColor,
                              ),
                            ),
                          ),

                          // Right Pane: Dopamine Synced Lyrics Ticker or Queue
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
                              child: _buildRightPanel(
                                context,
                                mornye: mornye,
                                colorScheme: colorScheme,
                                primaryAccent: primaryAccent,
                                panelBg: panelBg,
                                panelBorder: panelBorder,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top Dopamine navigation and utility bar
  Widget _buildHeaderBar(
    BuildContext context, {
    required bool mornye,
    required Color primaryAccent,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Close / Exit Fullscreen button
          if (widget.onClose != null)
            _RoundIconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: mornye ? CupertinoIcons.xmark : Icons.close_rounded,
              mornye: mornye,
              accentColor: primaryAccent,
              onPressed: widget.onClose!,
            ),

          const SizedBox(width: 12),

          // Dopamine Desktop Mode Indicator Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: mornye
                  ? const Color(0xFF141418)
                  : const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryAccent.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.album_rounded,
                  size: 14,
                  color: primaryAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'DOPAMINE DESKTOP AUDIO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: primaryAccent,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Audio Output Route Picker
          AudioOutputButton(
            color: mornye ? Colors.white : primaryAccent,
          ),

          const SizedBox(width: 8),

          // Equalizer Shortcut
          _RoundIconButton(
            tooltip: context.l10n.equalizerTitle,
            icon: Icons.tune_rounded,
            mornye: mornye,
            accentColor: primaryAccent,
            onPressed: () => pushPage<void>(context, (_) => const EqualizerScreen()),
          ),

          const SizedBox(width: 8),

          // Full-screen Toggle
          if (widget.onToggleFullScreen != null)
            _RoundIconButton(
              tooltip: widget.isFullScreen ? 'Exit Full Screen' : 'Full Screen',
              icon: widget.isFullScreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              mornye: mornye,
              accentColor: primaryAccent,
              onPressed: widget.onToggleFullScreen!,
            ),

          const SizedBox(width: 12),

          // Lyrics vs Queue Switcher Capsule
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: mornye
                  ? const Color(0xFF18181C)
                  : const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: primaryAccent.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CapsuleTab(
                  label: 'Lyrics',
                  icon: mornye ? CupertinoIcons.quote_bubble : Icons.lyrics_rounded,
                  selected: _currentPanel == DopamineDesktopPanel.lyrics,
                  mornye: mornye,
                  accentColor: primaryAccent,
                  onTap: () => setState(() => _currentPanel = DopamineDesktopPanel.lyrics),
                ),
                const SizedBox(width: 2),
                _CapsuleTab(
                  label: 'Up Next',
                  icon: mornye ? CupertinoIcons.list_bullet : Icons.queue_music_rounded,
                  selected: _currentPanel == DopamineDesktopPanel.queue,
                  mornye: mornye,
                  accentColor: primaryAccent,
                  onTap: () => setState(() => _currentPanel = DopamineDesktopPanel.queue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Left Pane Console: Platter, Live Telemetry HUD, Metadata, Seekbar, Controls
  Widget _buildLeftConsole(
    BuildContext context,
    BoxConstraints constraints, {
    required bool mornye,
    required ColorScheme colorScheme,
    required Color primaryAccent,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    // Dynamically calculate platter dimension to prevent overflow
    final availableHeight = constraints.maxHeight;
    final platterSize = math.min(availableHeight * 0.44, 300.0).clamp(160.0, 320.0);

    final subtitle = [
      widget.mediaItem.artist,
      widget.mediaItem.album,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Digital Spinning Vinyl Platter
          Center(
            child: TurntablePlatter(
              mediaItem: widget.mediaItem,
              size: platterSize,
              showTonearm: true,
              accentColor: primaryAccent,
            ),
          ),

          const SizedBox(height: 12),

          // 2. Real-Time Audio & DAC Telemetry HUD Pill
          AudioSignalTelemetryHud(
            mediaItem: widget.mediaItem,
            metadata: widget.metadata,
          ),

          const SizedBox(height: 14),

          // 3. Track Metadata (Title, Artist, Album, Actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.mediaItem.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Favorite Button
                MornyePlayerFavoriteButton(
                  mediaItem: widget.mediaItem,
                  color: primaryAccent,
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                ),
                // More Actions Context Menu
                _DopamineMoreButton(
                  mediaItem: widget.mediaItem,
                  metadata: widget.metadata,
                  colorScheme: colorScheme,
                  mornye: mornye,
                  accentColor: primaryAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 4. Playback Controls (Seekbar + Complete Transport)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: PlayerPlaybackControls(
              mediaId: widget.mediaItem.id,
              duration: widget.mediaItem.duration ?? Duration.zero,
              seekPreview: widget.seekPreview,
              colorScheme: colorScheme,
              metadata: widget.metadata,
              compact: true,
              showPlaybackModes: true,
            ),
          ),

          const SizedBox(height: 8),

          // 5. Volume Control Slider Capsule
          Container(
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: mornye
                  ? const Color(0xFF141418)
                  : const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryAccent.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: PlayerVolumeControl(
              foreground: titleColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Right Pane: Dopamine Synced Lyrics Ticker or Up Next Queue
  Widget _buildRightPanel(
    BuildContext context, {
    required bool mornye,
    required ColorScheme colorScheme,
    required Color primaryAccent,
    required Color panelBg,
    required Color panelBorder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: panelBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: mornye ? 0.40 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _currentPanel == DopamineDesktopPanel.lyrics
              ? KeyedSubtree(
                  key: const ValueKey('dopamine-lyrics-ticker'),
                  child: PlayerLyricsSection(
                    metadata: widget.metadata,
                    seekPreview: widget.seekPreview,
                    colorScheme: colorScheme,
                    isActive: true,
                    animateWords: true,
                    options: LyricsOptionsButton(
                      metadata: widget.metadata,
                      colorScheme: colorScheme,
                    ),
                    onShareLyrics: _shareLyrics,
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('dopamine-upnext-queue'),
                  child: NoScrollbars(
                    child: mornye
                        ? MornyePlayerQueue(colorScheme: colorScheme)
                        : DesktopMaterialQueue(colorScheme: colorScheme),
                  ),
                ),
        ),
      ),
    );
  }

  /// Narrow fallback for compact / split-screen landscape
  Widget _buildNarrowFallback(
    BuildContext context,
    BoxConstraints constraints,
    bool mornye,
    ColorScheme colorScheme,
    Color primaryAccent,
    Color titleColor,
    Color subtitleColor,
    Color panelBg,
    Color panelBorder,
  ) {
    return _buildLeftConsole(
      context,
      constraints,
      mornye: mornye,
      colorScheme: colorScheme,
      primaryAccent: primaryAccent,
      titleColor: titleColor,
      subtitleColor: subtitleColor,
    );
  }
}

/// Circular action button with Dopamine aesthetic
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.mornye,
    required this.accentColor,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool mornye;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mornye
                  ? Colors.white.withValues(alpha: 0.10)
                  : accentColor.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: mornye ? Colors.white : accentColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab selector inside top header capsule
class _CapsuleTab extends StatelessWidget {
  const _CapsuleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.mornye,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool mornye;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? (mornye ? Colors.white : Colors.white)
        : (mornye ? const Color(0xFFA1A1AA) : accentColor);
    final bg = selected ? accentColor : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// More options button for Dopamine player
class _DopamineMoreButton extends ConsumerWidget {
  const _DopamineMoreButton({
    required this.mediaItem,
    required this.metadata,
    required this.colorScheme,
    required this.mornye,
    required this.accentColor,
  });

  final MediaItem mediaItem;
  final PlayerMetadataController metadata;
  final ColorScheme colorScheme;
  final bool mornye;
  final Color accentColor;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final track = ref.read(playerCollectionTrackProvider(mediaItem)).value;
    final loved = track != null && ref.read(libraryCollectionsProvider).isLoved(track);

    MornyeMenuAction row(
      BuildContext menuContext,
      String value,
      String label, {
      IconData? icon,
      bool disclosure = false,
      bool selected = false,
    }) => MornyeMenuAction(
      icon: icon,
      label: label,
      disclosure: disclosure,
      selected: selected,
      onPressed: () => Navigator.of(menuContext).pop(value),
    );

    final anchor = mornyeMenuAnchor(context);
    final action = await showMornyeContextMenu<String>(
      context: context,
      anchor: anchor,
      preferAbove: true,
      maxWidth: 240,
      builder: (menuContext) => MornyeContextMenu(
        dense: true,
        groups: [
          [
            row(
              menuContext,
              'playlist',
              l10n.collectionAddToPlaylist,
              disclosure: true,
            ),
          ],
          [
            row(menuContext, 'details', l10n.mornyeGetInfo),
            row(
              menuContext,
              'favorite',
              loved ? l10n.mornyeFavorited : l10n.mornyeFavorite,
              selected: loved,
            ),
            row(menuContext, 'equalizer', l10n.equalizerTitle),
          ],
          [
            if ((mediaItem.album ?? '').trim().isNotEmpty)
              row(menuContext, 'album', l10n.homeGoToAlbum),
            if ((mediaItem.artist ?? '').trim().isNotEmpty)
              row(menuContext, 'artist', l10n.mornyeGoToArtist),
          ],
          [
            row(
              menuContext,
              'share',
              l10n.trackMetadataShare,
              icon: CupertinoIcons.share,
              disclosure: true,
            ),
          ],
        ],
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'playlist' || 'favorite':
        await _updateCollection(context, ref, favorite: action == 'favorite');
      case 'details':
        unawaited(
          showPlayerDetailsSheet(
            context,
            colorScheme,
            metadata: metadata,
            mediaItem: mediaItem,
          ),
        );
      case 'equalizer':
        await pushPage<void>(context, (_) => const EqualizerScreen());
      case 'album':
        await openPlayingAlbum(
          context,
          ref,
          mediaItem: mediaItem,
          source: mediaItem.extras?['source']?.toString() ?? '',
        );
      case 'artist':
        await openPlayingArtist(context, ref, mediaItem);
      case 'share':
        final artist = mediaItem.artist ?? '';
        await SharePlus.instance.share(
          ShareParams(
            text: artist.isEmpty
                ? mediaItem.title
                : '${mediaItem.title}, $artist',
            sharePositionOrigin: anchor,
          ),
        );
    }
  }

  Future<void> _updateCollection(
    BuildContext context,
    WidgetRef ref, {
    required bool favorite,
  }) async {
    try {
      final provider = playerCollectionTrackProvider(mediaItem);
      if (ref.read(provider).hasError) ref.invalidate(provider);
      final track = await ref.read(provider.future);
      if (!context.mounted) return;
      if (favorite) {
        await ref.read(libraryCollectionsProvider.notifier).toggleLoved(track);
      } else {
        await showAddTrackToPlaylistSheet(context, ref, track);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.snackbarError(context.friendlyError(error)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Builder(
    builder: (buttonContext) => IconButton(
      icon: const Icon(Icons.more_vert_rounded),
      color: mornye ? Colors.white : accentColor,
      iconSize: 20,
      onPressed: () => _open(buttonContext, ref),
    ),
  );
}
