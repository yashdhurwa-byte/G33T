import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/widgets/player_artwork.dart';

/// Interactive Digital Vinyl Platter (Turntable) widget.
///
/// Features:
/// - Continuous unidirectional rotation accumulator (no reverse snap-backs on pause, seek, or loop)
/// - Stylized realistic vinyl platter with specular sheen, concentric microgrooves, and center label
/// - Metallic spindle hole and spindle pin
/// - Gesture controls: tap to toggle play/pause, horizontal drag for scratching/manual rotation,
///   and horizontal swipe/fling to skip tracks.
class TurntablePlatter extends ConsumerStatefulWidget {
  const TurntablePlatter({
    super.key,
    required this.mediaItem,
    this.size,
    this.onTap,
    this.onDoubleTap,
    this.showTonearm = true,
    this.accentColor,
  });

  final MediaItem mediaItem;
  final double? size;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool showTonearm;
  final Color? accentColor;

  @override
  ConsumerState<TurntablePlatter> createState() => _TurntablePlatterState();
}

class _TurntablePlatterState extends ConsumerState<TurntablePlatter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _currentAngle = 0.0;
  bool _isDragging = false;

  // Rotation period for 33 1/3 RPM vinyl record: ~1.8 seconds per revolution.
  // Slightly relaxed for visual elegance: 3.6s per revolution.
  static const double _rotationPeriodSeconds = 3.6;
  static const double _angularSpeed = (2 * math.pi) / _rotationPeriodSeconds;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // Start ticker if player is already playing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isPlaying = ref.read(playbackPlayingProvider);
        if (isPlaying && !_ticker.isActive) {
          _lastElapsed = Duration.zero;
          _ticker.start();
        }
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (!_isDragging && dt > 0 && dt < 0.5) {
      // Monotonic unidirectional forward rotation
      setState(() {
        _currentAngle = (_currentAngle + dt * _angularSpeed) % (2 * math.pi);
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Scratching effect: delta horizontally adds to rotation
      _currentAngle = (_currentAngle + details.primaryDelta! * 0.015) % (2 * math.pi);
      if (_currentAngle < 0) {
        _currentAngle += 2 * math.pi;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0.0;
    const swipeThreshold = 350.0;

    if (velocity < -swipeThreshold) {
      // Swiped left -> skip to next track
      ref.read(musicPlayerControllerProvider).next();
    } else if (velocity > swipeThreshold) {
      // Swiped right -> skip to previous track
      ref.read(musicPlayerControllerProvider).previous();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(playbackPlayingProvider);

    // Keep ticker in sync with playback state
    if (isPlaying && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!isPlaying && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDimension = math.min(constraints.maxWidth, constraints.maxHeight);
        final diameter = widget.size ?? (maxDimension.isFinite && maxDimension > 0 ? maxDimension : 320.0);
        final platterSize = diameter.clamp(160.0, 480.0);
        final labelDiameter = platterSize * 0.40;

        return Center(
          child: SizedBox(
            width: platterSize,
            height: platterSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap ??
                  () => ref.read(musicPlayerControllerProvider).togglePlayPause(isPlaying),
              onDoubleTap: widget.onDoubleTap,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Spinning vinyl platter surface
                  Transform.rotate(
                    angle: _currentAngle,
                    child: SizedBox(
                      width: platterSize,
                      height: platterSize,
                      child: CustomPaint(
                        painter: const _VinylRecordPainter(),
                        child: Center(
                          // Center circular album artwork label
                          child: Container(
                            width: labelDiameter,
                            height: labelDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: labelDiameter,
                                    height: labelDiameter,
                                    child: PlayerArtwork(
                                      artUri: widget.mediaItem.artUri?.toString(),
                                      colorScheme: Theme.of(context).colorScheme,
                                      cacheWidth: (labelDiameter * MediaQuery.devicePixelRatioOf(context)).round(),
                                    ),
                                  ),
                                  // Subtle paper label overlay rim
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  // Center Spindle Hole (metallic ring + black center)
                                  Container(
                                    width: platterSize * 0.065,
                                    height: platterSize * 0.065,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1E1E1E),
                                      border: Border.all(
                                        color: const Color(0xFFD4D4D8),
                                        width: 2.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.8),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Center spindle pin
                                  Container(
                                    width: platterSize * 0.025,
                                    height: platterSize * 0.025,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFE4E4E7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tonearm overlay (optional, rests on record when playing)
                  if (widget.showTonearm)
                    Positioned(
                      top: 4,
                      right: 12,
                      child: AnimatedRotation(
                        turns: isPlaying ? 0.04 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topRight,
                        child: _TonearmWidget(accentColor: widget.accentColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the vinyl record disk, grooves, and specular sheen.
class _VinylRecordPainter extends CustomPainter {
  const _VinylRecordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Vinyl base body (deep satin vinyl black)
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF222224),
          Color(0xFF141416),
          Color(0xFF0A0A0C),
          Color(0xFF050506),
        ],
        stops: const [0.0, 0.5, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, basePaint);

    // 2. Beveled outer rim
    final outerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF3F3F46);
    canvas.drawCircle(center, radius - 1.0, outerRimPaint);

    // 3. Realistic vinyl specular sheen (dual opposing light cones)
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.02),
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.50, 0.55, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius - 4, sheenPaint);

    // 4. Concentric microgrooves
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.035);

    final innerLimit = radius * 0.42;
    final outerLimit = radius * 0.94;
    const grooveSteps = 28;
    final step = (outerLimit - innerLimit) / grooveSteps;

    for (int i = 0; i <= grooveSteps; i++) {
      final r = innerLimit + i * step;
      canvas.drawCircle(center, r, groovePaint);
    }

    // 5. Run-out groove band near center label
    final runOutPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(center, radius * 0.43, runOutPaint);
    canvas.drawCircle(center, radius * 0.45, runOutPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylRecordPainter oldDelegate) => false;
}

/// Sleek phonograph tonearm
class _TonearmWidget extends StatelessWidget {
  const _TonearmWidget({this.accentColor});

  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size(64, 110),
        painter: _TonearmPainter(accentColor: accentColor),
      ),
    );
  }
}

class _TonearmPainter extends CustomPainter {
  const _TonearmPainter({this.accentColor});

  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Pivot base
    final pivotCenter = Offset(size.width - 16, 16);
    final pivotPaint = Paint()..color = const Color(0xFF52525B);
    canvas.drawCircle(pivotCenter, 10, pivotPaint);

    final pivotInner = Paint()..color = const Color(0xFFA1A1AA);
    canvas.drawCircle(pivotCenter, 5, pivotInner);

    // Arm line
    final armPath = Path()
      ..moveTo(pivotCenter.dx, pivotCenter.dy)
      ..quadraticBezierTo(size.width - 20, size.height * 0.55, 12, size.height - 14);

    final armPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4D4D8);

    canvas.drawPath(armPath, armPaint);

    // Headshell / Cartridge at tip
    final cartridgePaint = Paint()..color = accentColor ?? const Color(0xFF8B5CF6);
    final cartridgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(12, 98), width: 10, height: 16),
      const Radius.circular(2),
    );
    canvas.drawRRect(cartridgeRect, cartridgePaint);
  }

  @override
  bool shouldRepaint(covariant _TonearmPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
