import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/services/playback_telemetry_engine.dart';
import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/utils/adaptive_layout.dart';
import 'package:mornye/widgets/app_icon.dart';
import 'package:mornye/widgets/app_loading_indicator.dart';
import 'package:mornye/widgets/app_sliver_header.dart';
import 'package:mornye/widgets/cached_cover_image.dart';

/// Dedicated Listening Telemetry & Analytics Dashboard Screen.
///
/// Visual breakdowns of:
/// - Total verified play counts and cumulative listening time
/// - Completion ratio vs. early skips
/// - Most-played tracks, albums, and folders
/// - Signal & DAC audio quality distribution
///
/// Adapts dynamically to Engine A (Mornye AMOLED) and Engine B (Material UI).
class TelemetryDashboardScreen extends ConsumerStatefulWidget {
  const TelemetryDashboardScreen({super.key});

  @override
  ConsumerState<TelemetryDashboardScreen> createState() =>
      _TelemetryDashboardScreenState();
}

class _TelemetryDashboardScreenState
    extends ConsumerState<TelemetryDashboardScreen> {
  int? _selectedDays = 30; // null = all time, 7, 30
  bool _loading = true;

  TelemetryOverview? _overview;
  List<TopTrackStat> _topTracks = const [];
  List<TopAlbumStat> _topAlbums = const [];
  List<TopFolderStat> _topFolders = const [];
  QualityDistribution? _quality;

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
  }

  Future<void> _loadTelemetry() async {
    setState(() => _loading = true);
    final engine = PlaybackTelemetryEngine.instance;

    final overview = await engine.getOverview(days: _selectedDays);
    final tracks = await engine.getTopTracks(limit: 10, days: _selectedDays);
    final albums = await engine.getTopAlbums(limit: 8, days: _selectedDays);
    final folders = await engine.getTopFolders(limit: 6, days: _selectedDays);
    final quality = await engine.getQualityDistribution(days: _selectedDays);

    if (mounted) {
      setState(() {
        _overview = overview;
        _topTracks = tracks;
        _topAlbums = albums;
        _topFolders = folders;
        _quality = quality;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMornye = context.isMornye;

    // Theme Engine Colors
    final bgColor = isMornye ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final cardColor = isMornye ? const Color(0xFF121214) : const Color(0xFFFCE4EC);
    final primaryAccent = isMornye ? const Color(0xFF8B5CF6) : const Color(0xFF6A1B9A);
    final textColor = isMornye ? const Color(0xFFFFFFFF) : const Color(0xFF1E1E1E);
    final subtitleColor = isMornye ? const Color(0xFFA1A1AA) : const Color(0xFF4A148C);
    final borderColor = isMornye ? const Color(0xFF27272A) : const Color(0xFFF8BBD0);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          AppSliverHeader.page(
            title: 'Listening Telemetry',
            actions: [
              IconButton(
                icon: const AppIcon(Icons.refresh),
                tooltip: 'Refresh Telemetry',
                onPressed: _loadTelemetry,
              ),
            ],
          ),

          // Time filter segment row
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0 + wideListInset(context),
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  _buildPeriodPill('7 Days', 7, isMornye, primaryAccent, cardColor, textColor),
                  const SizedBox(width: 8),
                  _buildPeriodPill('30 Days', 30, isMornye, primaryAccent, cardColor, textColor),
                  const SizedBox(width: 8),
                  _buildPeriodPill('All Time', null, isMornye, primaryAccent, cardColor, textColor),
                ],
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: AppLoadingIndicator()),
            )
          else ...[
            // KPI Summary Grid
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0 + wideListInset(context),
                vertical: 12.0,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildSummaryCards(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  primaryAccent: primaryAccent,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  isMornye: isMornye,
                ),
              ),
            ),

            // Quality Distribution Breakdown
            if (_quality != null && _quality!.total > 0)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0 + wideListInset(context),
                  vertical: 8.0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildQualitySection(
                    cardColor: cardColor,
                    borderColor: borderColor,
                    primaryAccent: primaryAccent,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
              ),

            // Top Tracks Section
            _buildSectionHeader('Most Played Tracks', Icons.music_note_rounded, primaryAccent, textColor),
            if (_topTracks.isEmpty)
              _buildEmptySection('No track playback logged for this period yet.')
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0 + wideListInset(context),
                  vertical: 8.0,
                ),
                sliver: SliverList.builder(
                  itemCount: _topTracks.length,
                  itemBuilder: (context, index) => _buildTrackCard(
                    rank: index + 1,
                    stat: _topTracks[index],
                    cardColor: cardColor,
                    borderColor: borderColor,
                    primaryAccent: primaryAccent,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
              ),

            // Top Albums Section
            _buildSectionHeader('Top Albums', Icons.album_rounded, primaryAccent, textColor),
            if (_topAlbums.isEmpty)
              _buildEmptySection('No album playback logged for this period.')
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0 + wideListInset(context),
                  vertical: 8.0,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 210,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildAlbumCard(
                      stat: _topAlbums[index],
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primaryAccent: primaryAccent,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                    ),
                    childCount: _topAlbums.length,
                  ),
                ),
              ),

            // Top Folders Section
            _buildSectionHeader('Top Folders & Directories', Icons.folder_rounded, primaryAccent, textColor),
            if (_topFolders.isEmpty)
              _buildEmptySection('No folder playback logged for this period.')
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0 + wideListInset(context),
                  vertical: 8.0,
                ),
                sliver: SliverList.builder(
                  itemCount: _topFolders.length,
                  itemBuilder: (context, index) => _buildFolderCard(
                    stat: _topFolders[index],
                    cardColor: cardColor,
                    borderColor: borderColor,
                    primaryAccent: primaryAccent,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodPill(
    String label,
    int? days,
    bool isMornye,
    Color accent,
    Color cardColor,
    Color textColor,
  ) {
    final selected = _selectedDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: accent,
      backgroundColor: cardColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : textColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() => _selectedDays = days);
        _loadTelemetry();
      },
    );
  }

  Widget _buildSummaryCards({
    required Color cardColor,
    required Color borderColor,
    required Color primaryAccent,
    required Color textColor,
    required Color subtitleColor,
    required bool isMornye,
  }) {
    final overview = _overview ??
        const TelemetryOverview(
          totalListeningMs: 0,
          totalPlays: 0,
          totalCompletions: 0,
          totalSkips: 0,
          totalTracks: 0,
        );

    final ratioPct = (overview.completionRatio * 100).toStringAsFixed(0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.timer_outlined,
                title: 'Cumulative Time',
                value: overview.formattedListeningTime,
                cardColor: cardColor,
                borderColor: borderColor,
                accentColor: primaryAccent,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.play_circle_fill_rounded,
                title: 'Verified Plays',
                value: '${overview.totalPlays}',
                cardColor: cardColor,
                borderColor: borderColor,
                accentColor: primaryAccent,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AppIcon(Icons.pie_chart_outline_rounded, color: primaryAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Completion Ratio vs. Skips',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$ratioPct% Completed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: overview.completionRatio,
                  minHeight: 10,
                  backgroundColor: isMornye ? const Color(0xFF27272A) : const Color(0xFFFFCDD2),
                  color: primaryAccent,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${overview.totalCompletions} finished',
                    style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${overview.totalSkips} early skips',
                    style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required Color cardColor,
    required Color borderColor,
    required Color accentColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, color: accentColor, size: 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySection({
    required Color cardColor,
    required Color borderColor,
    required Color primaryAccent,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final q = _quality!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Signal & Quality Distribution',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQualityBadge('Hi-Res (24-bit/96kHz+)', q.hiResCount, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildQualityBadge('CD (16-bit FLAC)', q.cdQualityCount, primaryAccent),
              const SizedBox(width: 8),
              _buildQualityBadge('Lossy', q.lossyCount, const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color accent, Color textColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            AppIcon(icon, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard({
    required int rank,
    required TopTrackStat stat,
    required Color cardColor,
    required Color borderColor,
    required Color primaryAccent,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryAccent.withValues(alpha: rank <= 3 ? 0.9 : 0.2),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? Colors.white : primaryAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Artwork thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: stat.artwork != null && stat.artwork!.isNotEmpty
                  ? CachedCoverImage(
                      imageUrl: stat.artwork!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: cardColor),
                      errorWidget: (_, _, _) => Container(color: cardColor),
                    )
                  : Container(
                      color: primaryAccent.withValues(alpha: 0.1),
                      child: Icon(Icons.music_note, color: primaryAccent, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '${stat.artist} · ${stat.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
              ],
            ),
          ),

          // Plays and time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stat.plays} plays',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryAccent),
              ),
              Text(
                stat.formattedDuration,
                style: TextStyle(fontSize: 11, color: subtitleColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard({
    required TopAlbumStat stat,
    required Color cardColor,
    required Color borderColor,
    required Color primaryAccent,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                child: stat.artwork != null && stat.artwork!.isNotEmpty
                    ? CachedCoverImage(
                        imageUrl: stat.artwork!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: cardColor),
                        errorWidget: (_, _, _) => Container(color: cardColor),
                      )
                    : Container(
                        color: primaryAccent.withValues(alpha: 0.15),
                        child: Icon(Icons.album, color: primaryAccent, size: 40),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat.album,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
          ),
          Text(
            stat.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: subtitleColor),
          ),
          Text(
            '${stat.plays} plays · ${stat.formattedListeningTime}',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard({
    required TopFolderStat stat,
    required Color cardColor,
    required Color borderColor,
    required Color primaryAccent,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.folder_open_rounded, color: primaryAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.folderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  stat.folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: subtitleColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stat.plays} plays',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryAccent),
              ),
              Text(
                stat.formattedListeningTime,
                style: TextStyle(fontSize: 11, color: subtitleColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
