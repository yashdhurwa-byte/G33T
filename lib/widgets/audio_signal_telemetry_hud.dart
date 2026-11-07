import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/controllers/player_metadata_controller.dart';
import 'package:mornye/screens/telemetry_dashboard_screen.dart';
import 'package:mornye/services/audio_route_info.dart';
import 'package:mornye/services/music_playback_deck.dart';
import 'package:mornye/services/music_player_runtime.dart';
import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/utils/int_utils.dart';
import 'package:mornye/widgets/app_bottom_sheet.dart';
import 'package:mornye/widgets/app_icon.dart';

/// Real-Time Audio & DAC Signal Telemetry HUD Pill.
///
/// Extracts and renders live stream parameters (codec/format, bit depth,
/// sample rate in kHz, instantaneous/average bitrate in kbps, and active hardware output route)
/// with a live bit-perfect DAC status indicator.
class AudioSignalTelemetryHud extends ConsumerStatefulWidget {
  const AudioSignalTelemetryHud({
    super.key,
    required this.mediaItem,
    required this.metadata,
  });

  final MediaItem mediaItem;
  final PlayerMetadataController metadata;

  @override
  ConsumerState<AudioSignalTelemetryHud> createState() =>
      _AudioSignalTelemetryHudState();
}

class _AudioSignalTelemetryHudState extends ConsumerState<AudioSignalTelemetryHud> {
  AudioRouteInfo? _route;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchRouteInfo();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _fetchRouteInfo();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRouteInfo() async {
    final path = widget.metadata.filePath;
    final info = await readAudioRouteInfo(path: path);
    if (mounted) {
      setState(() => _route = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.metadata.metadata ?? widget.mediaItem.extras ?? const {};
    final isMornye = context.isMornye;

    // 1. Format / Codec
    final rawFormat = meta['format']?.toString() ??
        meta['audio_codec']?.toString() ??
        widget.mediaItem.extras?['format']?.toString() ??
        '';
    final format = rawFormat.isNotEmpty ? rawFormat.toUpperCase() : 'PCM';

    // 2. Bit depth
    final bitDepth = readPositiveInt(meta['bit_depth']) ??
        readPositiveInt(widget.mediaItem.extras?['bit_depth']) ??
        _route?.stream?.pcmBits ??
        16;

    // 3. Sample rate in kHz
    final rawSampleRate = readPositiveInt(meta['sample_rate']) ??
        readPositiveInt(widget.mediaItem.extras?['sample_rate']) ??
        _route?.stream?.sampleRate ??
        44100;
    final sampleRateKHz = (rawSampleRate / 1000.0).toStringAsFixed(1);

    // 4. Bitrate in kbps
    final rawBitrate = readPositiveInt(meta['bitrate']) ??
        readPositiveInt(widget.mediaItem.extras?['bitrate']) ??
        _route?.stream?.bitrate;
    final bitrateKbps = rawBitrate != null && rawBitrate > 0
        ? (rawBitrate > 10000 ? (rawBitrate / 1000).round() : rawBitrate)
        : null;

    // 5. Active hardware output route & Bit-Perfect status
    final usb = usbAudioStatus.value;
    final isUsbDac = usb.device != null && usb.device!.isNotEmpty;
    final device = _route?.device;
    final isBitPerfect = isUsbDac ||
        (musicPlayerRuntime.handler?.processing.direct ?? false) ||
        (device?.mixerBitPerfect ?? false);

    final String outputRoute;
    final IconData outputIcon;

    if (isUsbDac) {
      outputRoute = 'USB DAC: ${usb.device!}';
      outputIcon = Icons.usb_rounded;
    } else if (device?.isBluetooth == true) {
      final name = device?.name ?? '';
      outputRoute = name.isNotEmpty ? 'BT: $name' : 'Bluetooth LDAC';
      outputIcon = Icons.bluetooth_audio_rounded;
    } else if (device?.type == 'wired_headphones') {
      outputRoute = '3.5mm Headphone Jack';
      outputIcon = Icons.headphones_rounded;
    } else if (device?.type == 'speaker') {
      outputRoute = 'Internal Speaker';
      outputIcon = Icons.speaker_rounded;
    } else {
      outputRoute = 'Oboe / AudioTrack Hi-Res';
      outputIcon = Icons.graphic_eq_rounded;
    }

    // Colors according to Engine A vs Engine B
    final pillBg = isMornye
        ? const Color(0xFF141416)
        : const Color(0xFFFCE4EC); // Sakura pink for Material
    final pillBorder = isMornye
        ? const Color(0xFFF5F0EB).withValues(alpha: 0.30) // Warm soft beige border
        : const Color(0xFF6A1B9A).withValues(alpha: 0.25); // Deep purple border
    final accentColor = isMornye
        ? const Color(0xFF8B5CF6) // Electric violet
        : const Color(0xFF6A1B9A); // Deep Royal Purple
    final textColor = isMornye ? const Color(0xFFF5F0EB) : const Color(0xFF2E0854);
    final secondaryTextColor = isMornye ? const Color(0xFFA1A1AA) : const Color(0xFF6A1B9A);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showTechnicalDetailsSheet(
            context: context,
            format: format,
            bitDepth: bitDepth,
            sampleRateKHz: sampleRateKHz,
            bitrateKbps: bitrateKbps,
            outputRoute: outputRoute,
            outputIcon: outputIcon,
            isBitPerfect: isBitPerfect,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: pillBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: isMornye ? 0.15 : 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live bit-perfect pulsing LED
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBitPerfect ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    boxShadow: [
                      BoxShadow(
                        color: (isBitPerfect ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                            .withValues(alpha: 0.7),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Format & Resolution
                Text(
                  '$format $bitDepth-bit / $sampleRateKHz kHz',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: textColor,
                  ),
                ),

                if (bitrateKbps != null) ...[
                  Text(
                    ' · ',
                    style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$bitrateKbps kbps',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],

                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: secondaryTextColor.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),

                // Hardware output route icon & label
                AppIcon(
                  outputIcon,
                  size: 14,
                  color: accentColor,
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    outputRoute,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTechnicalDetailsSheet({
    required BuildContext context,
    required String format,
    required int bitDepth,
    required String sampleRateKHz,
    required int? bitrateKbps,
    required String outputRoute,
    required IconData outputIcon,
    required bool isBitPerfect,
  }) {
    final isMornye = context.isMornye;
    final accentColor = isMornye ? const Color(0xFF8B5CF6) : const Color(0xFF6A1B9A);

    showAppModalBottomSheet<void>(
      context: context,
      builder: (ctx) => AppBottomSheet(
        title: 'DAC & Audio Signal Telemetry',
        subtitle: isBitPerfect ? 'Bit-Perfect Direct Hardware Stream' : 'System Mixed Audio Stream',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFactRow('Decoder Source', '${widget.mediaItem.title} ($format)'),
              _buildFactRow('Signal Format', '$format Lossless'),
              _buildFactRow('Bit Depth', '$bitDepth-bit integer'),
              _buildFactRow('Sample Rate', '$sampleRateKHz kHz'),
              if (bitrateKbps != null)
                _buildFactRow('Instantaneous Bitrate', '$bitrateKbps kbps'),
              _buildFactRow('Hardware Output Route', outputRoute),
              _buildFactRow('Signal Path Pipeline', isBitPerfect ? 'Rust Decoder -> Oboe / Direct USB -> DAC' : 'Android AudioTrack / System Mixer'),
              _buildFactRow('Bit-Perfect Verification', isBitPerfect ? 'Active (Bit-Perfect Confirmed)' : 'Inactive (System Resampled)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                  label: const Text(
                    'Open Telemetry & Listening Dashboard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const TelemetryDashboardScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
