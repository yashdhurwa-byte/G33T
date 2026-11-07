import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mornye/controllers/player_metadata_controller.dart';
import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/utils/playback_seek_preview.dart';
import 'package:mornye/widgets/audio_signal_telemetry_hud.dart';
import 'package:mornye/widgets/player_playback_controls.dart';
import 'package:mornye/widgets/player_volume_control.dart';

/// Floating Glass Control Dock Pill (BackdropFilter)
///
/// Features:
/// - Real-time frosted glass blur via [BackdropFilter]
/// - Embedded live hardware DAC signal telemetry badge
/// - Precision seekbar with smooth thumb glow
/// - Tactile playback transport dock (Shuffle, Prev, Play/Pause with theme glow, Next, Repeat)
/// - Volume slider integration
/// - Complete Theme Engine synchronization:
///   * Engine A (Mornye): Dark glass, #8B5CF6 electric violet accents, #FFFFFF white controls
///   * Engine B (Material): Sakura pink glass, #6A1B9A Deep Royal Purple accents
class FloatingGlassControlDock extends ConsumerWidget {
  const FloatingGlassControlDock({
    super.key,
    required this.mediaItem,
    required this.metadata,
    required this.seekPreview,
    this.showTelemetry = true,
    this.showVolume = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final MediaItem mediaItem;
  final PlayerMetadataController metadata;
  final PlaybackSeekPreview seekPreview;
  final bool showTelemetry;
  final bool showVolume;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mornye = context.isMornye;
    final theme = mornye
        ? MornyeTheme.fromContext(context, brightness: Brightness.dark)
        : Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Theme Engine Colors
    // Engine A: #000000 AMOLED black, #8B5CF6 electric violet, #FFFFFF stark white
    // Engine B: #FFFFFF background, #FCE4EC Sakura pink, #6A1B9A Deep Royal Purple
    final primaryAccent = mornye ? const Color(0xFF8B5CF6) : const Color(0xFF6A1B9A);
    final dockBg = mornye
        ? const Color(0xFF0F0F14).withValues(alpha: 0.72)
        : const Color(0xFFFCE4EC).withValues(alpha: 0.82);
    final dockBorder = mornye
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
        : const Color(0xFF6A1B9A).withValues(alpha: 0.25);
    final titleColor = mornye ? Colors.white : const Color(0xFF1D1B20);

    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: dockBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: dockBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withValues(alpha: mornye ? 0.25 : 0.12),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Live DAC Telemetry Badge
                if (showTelemetry) ...[
                  AudioSignalTelemetryHud(
                    mediaItem: mediaItem,
                    metadata: metadata,
                  ),
                  const SizedBox(height: 8),
                ],

                // 2. Playback Controls (Seekbar + Full Transport)
                PlayerPlaybackControls(
                  mediaId: mediaItem.id,
                  duration: mediaItem.duration ?? Duration.zero,
                  seekPreview: seekPreview,
                  colorScheme: colorScheme,
                  metadata: metadata,
                  compact: true,
                  showPlaybackModes: true,
                ),

                // 3. Integrated Volume Slider Capsule
                if (showVolume) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: mornye
                          ? Colors.white.withValues(alpha: 0.08)
                          : primaryAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
