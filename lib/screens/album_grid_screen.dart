import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/l10n/l10n.dart';
import 'package:mornye/providers/library_browse_provider.dart';
import 'package:mornye/screens/local_album_screen.dart';
import 'package:mornye/utils/adaptive_layout.dart';
import 'package:mornye/widgets/app_icon.dart';
import 'package:mornye/widgets/app_loading_indicator.dart';
import 'package:mornye/widgets/app_sliver_header.dart';
import 'package:mornye/widgets/cached_cover_image.dart';
import 'package:mornye/widgets/error_card.dart';
import 'package:mornye/widgets/sliver_layout_info_builder.dart';

/// Offline Album Grid Screen wired to sqflite + SAF and local custom cover cache.
class AlbumGridScreen extends ConsumerStatefulWidget {
  const AlbumGridScreen({super.key});

  @override
  ConsumerState<AlbumGridScreen> createState() => _AlbumGridScreenState();
}

class _AlbumGridScreenState extends ConsumerState<AlbumGridScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sort = 'a-z';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LibraryBrowseRequest get _query => (
        artists: false,
        artist: null,
        search: _searchQuery,
        sort: _sort,
        limit: 100,
        completeness: null,
      );

  @override
  Widget build(BuildContext context) {
    final browseState = ref.watch(libraryBrowseProvider(_query));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          AppSliverHeader.page(
            title: context.l10n.searchAlbums,
            actions: [
              PopupMenuButton<String>(
                icon: const AppIcon(Icons.sort),
                tooltip: context.l10n.searchSortTitle,
                onSelected: (option) => setState(() => _sort = option),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'a-z',
                    child: Text(context.l10n.searchSortTitleAZ),
                  ),
                  PopupMenuItem(
                    value: 'latest',
                    child: Text(context.l10n.libraryRecentlyAdded),
                  ),
                ],
              ),
            ],
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0 + wideListInset(context),
                vertical: 8.0,
              ),
              child: SearchBar(
                controller: _searchController,
                hintText: context.l10n.librarySearchHint,
                leading: const AppIcon(Icons.search),
                trailing: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const AppIcon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
                onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              ),
            ),
          ),

          // Grid or state
          browseState.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: AppLoadingIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: EmptyState(
                icon: Icons.error_outline,
                title: context.l10n.dialogRetry,
                message: err.toString(),
              ),
            ),
            data: (data) {
              var albums = data.entries;
              if (_searchQuery.isNotEmpty) {
                albums = albums.where((entry) {
                  final nameMatch = entry.name.toLowerCase().contains(_searchQuery);
                  final artistMatch = entry.artist.toLowerCase().contains(_searchQuery);
                  return nameMatch || artistMatch;
                }).toList(growable: false);
              }

              if (albums.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.album_outlined,
                    title: context.l10n.libraryEmptyCollection,
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0 + wideListInset(context),
                  vertical: 12.0,
                ),
                sliver: SliverLayoutInfoBuilder<double>(
                  select: (constraints) => constraints.crossAxisExtent,
                  builder: (context, extent) {
                    const minTileWidth = 160.0;
                    const spacing = 16.0;
                    final crossAxisCount = math.max(
                      2,
                      (extent / (minTileWidth + spacing)).floor(),
                    );
                    final tileWidth = (extent - spacing * (crossAxisCount - 1)) / crossAxisCount;
                    final tileHeight = tileWidth + 68.0;

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        mainAxisExtent: tileHeight,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = albums[index];
                          return _AlbumGridCard(
                            entry: album,
                            tileWidth: tileWidth,
                          );
                        },
                        childCount: albums.length,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AlbumGridCard extends ConsumerWidget {
  const _AlbumGridCard({
    required this.entry,
    required this.tileWidth,
  });

  final LibraryBrowseEntry entry;
  final double tileWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => LocalAlbumScreen(
              albumName: entry.name,
              artistName: entry.artist,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Cover Artwork
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colors.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: entry.cover != null && entry.cover!.isNotEmpty
                    ? CachedCoverImage(
                        imageUrl: entry.cover!,
                        width: tileWidth,
                        height: tileWidth,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _albumPlaceholder(colors),
                        placeholder: (_, _) => _albumPlaceholder(colors),
                      )
                    : _albumPlaceholder(colors),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Album Name
          Text(
            entry.name.isNotEmpty ? entry.name : 'Unknown Album',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          // Artist Name
          Text(
            entry.artist.isNotEmpty ? entry.artist : 'Unknown Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _albumPlaceholder(ColorScheme colors) => Container(
        color: colors.surfaceContainerHighest,
        child: Center(
          child: AppIcon(
            Icons.album_outlined,
            size: 40,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
}
