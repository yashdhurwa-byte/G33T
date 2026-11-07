import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/widgets/player_artwork.dart';

/// Item in the 3D Cascading Cover Flow
class CoverFlowItem {
  const CoverFlowItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.artUri,
    this.duration,
    this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final Uri? artUri;
  final Duration? duration;
  final VoidCallback? onTap;

  factory CoverFlowItem.fromMediaItem(MediaItem item, {VoidCallback? onTap}) {
    return CoverFlowItem(
      id: item.id,
      title: item.title,
      subtitle: [item.artist, item.album].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · '),
      artUri: item.artUri,
      duration: item.duration,
      onTap: onTap,
    );
  }
}

/// Cascading Cover Flow / 3D Album Selection Carousel using Matrix4 perspective transforms.
///
/// Features:
/// - True 3D perspective projection (Matrix4.identity()..setEntry(3, 2, 0.0016))
/// - Cascading angled side sleeves with depth attenuation, dynamic Z-stacking, and dark falloff
/// - Realistic mirror floor reflection with gradient falloff mask
/// - Dynamic center focus with theme-synchronized halo glow
/// - Smooth interactive swipe, page snaps, and tap-to-select
class SpatialCoverFlow extends ConsumerStatefulWidget {
  const SpatialCoverFlow({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onItemChanged,
    this.height = 360,
    this.cardSize = 220,
    this.showReflection = true,
    this.showMetadata = true,
  });

  final List<CoverFlowItem> items;
  final int initialIndex;
  final ValueChanged<int>? onItemChanged;
  final double height;
  final double cardSize;
  final bool showReflection;
  final bool showMetadata;

  @override
  ConsumerState<SpatialCoverFlow> createState() => _SpatialCoverFlowState();
}

class _SpatialCoverFlowState extends ConsumerState<SpatialCoverFlow> {
  late final PageController _pageController;
  late double _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex.toDouble();
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.52,
    )..addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted && _pageController.hasClients) {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    }
  }

  @override
  void didUpdateWidget(SpatialCoverFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex &&
        _pageController.hasClients &&
        (_pageController.page?.round() != widget.initialIndex)) {
      _pageController.animateToPage(
        widget.initialIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mornye = context.isMornye;
    final primaryAccent = mornye ? const Color(0xFF8B5CF6) : const Color(0xFF6A1B9A);
    final titleColor = mornye ? const Color(0xFFF5F0EB) : const Color(0xFF1D1B20);
    final subtitleColor = mornye ? const Color(0xFFA1A1AA) : const Color(0xFF6A1B9A);

    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No items in queue',
            style: TextStyle(color: subtitleColor, fontSize: 14),
          ),
        ),
      );
    }

    final currentIndex = _currentPage.round().clamp(0, widget.items.length - 1);
    final currentItem = widget.items[currentIndex];

    return SizedBox(
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3D Perspective Cover Flow Carousel
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                widget.onItemChanged?.call(index);
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final delta = index - _currentPage;
                final isSelected = (index == currentIndex);

                // 3D Perspective Transformation
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0018); // Perspective distortion

                // Rotate along Y-axis based on distance from center
                final angle = (delta * -0.55).clamp(-0.85, 0.85);
                transform.rotateY(angle);

                // Push side items back in Z-space
                final zTranslation = -100.0 * delta.abs();
                transform.setTranslationRaw(0.0, 0.0, zTranslation);

                // Scale attenuation
                final scale = (1.0 - (delta.abs() * 0.16)).clamp(0.68, 1.0);

                return Center(
                  child: Transform(
                    transform: transform,
                    alignment: delta < 0 ? Alignment.centerRight : Alignment.centerLeft,
                    child: Transform.scale(
                      scale: scale,
                      child: GestureDetector(
                        onTap: () {
                          if (index != currentIndex) {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeInOutCubic,
                            );
                          } else {
                            item.onTap?.call();
                          }
                        },
                        child: _CoverFlowCard(
                          item: item,
                          size: widget.cardSize,
                          isSelected: isSelected,
                          mornye: mornye,
                          primaryAccent: primaryAccent,
                          showReflection: widget.showReflection,
                          fadeFactor: (delta.abs() * 0.40).clamp(0.0, 0.70),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Metadata Info Overlay for Center Album
          if (widget.showMetadata) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(currentItem.id),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentItem.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (currentItem.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        currentItem.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
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
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Single 3D Cover Flow Album Sleeve with Glass Floor Reflection
class _CoverFlowCard extends StatelessWidget {
  const _CoverFlowCard({
    required this.item,
    required this.size,
    required this.isSelected,
    required this.mornye,
    required this.primaryAccent,
    required this.showReflection,
    required this.fadeFactor,
  });

  final CoverFlowItem item;
  final double size;
  final bool isSelected;
  final bool mornye;
  final Color primaryAccent;
  final bool showReflection;
  final double fadeFactor;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(mornye ? 12 : 20);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Primary Album Sleeve Card
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: isSelected
                  ? primaryAccent
                  : (mornye ? Colors.white12 : Colors.black12),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? primaryAccent.withValues(alpha: mornye ? 0.45 : 0.25)
                    : Colors.black.withValues(alpha: mornye ? 0.50 : 0.15),
                blurRadius: isSelected ? 24 : 14,
                spreadRadius: isSelected ? 2 : 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PlayerArtwork(
                  artUri: item.artUri?.toString(),
                  colorScheme: Theme.of(context).colorScheme,
                ),
                // Depth falloff darkness overlay for perspective realism
                if (fadeFactor > 0.02)
                  Container(
                    color: Colors.black.withValues(alpha: fadeFactor),
                  ),
                // Vinyl sleeve sheen reflection
                CustomPaint(
                  painter: _SleeveSheenPainter(),
                ),
              ],
            ),
          ),
        ),

        // 2. Glass Mirror Floor Reflection (Fading downward)
        if (showReflection)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: size,
              height: size * 0.28,
              child: ClipRect(
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationX(math.pi),
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: PlayerArtwork(
                        artUri: item.artUri?.toString(),
                        colorScheme: Theme.of(context).colorScheme,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Subtle diagonal specular gloss sheen on vinyl album sleeve
class _SleeveSheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.04),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
