import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:mornye/services/music_player_runtime.dart';
import 'package:mornye/services/sqlite_helpers.dart' as sqlite;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Telemetry overview statistics for a given time window.
class TelemetryOverview {
  final int totalListeningMs;
  final int totalPlays;
  final int totalCompletions;
  final int totalSkips;
  final int totalTracks;

  const TelemetryOverview({
    required this.totalListeningMs,
    required this.totalPlays,
    required this.totalCompletions,
    required this.totalSkips,
    required this.totalTracks,
  });

  double get completionRatio {
    final total = totalCompletions + totalSkips;
    if (total == 0) return totalPlays > 0 ? 1.0 : 0.0;
    return (totalCompletions / total).clamp(0.0, 1.0);
  }

  String get formattedListeningTime {
    final seconds = totalListeningMs ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Statistics for a single top-played track.
class TopTrackStat {
  final String trackKey;
  final String title;
  final String artist;
  final String album;
  final String? artwork;
  final int plays;
  final int totalListeningMs;
  final int completions;
  final int skips;

  const TopTrackStat({
    required this.trackKey,
    required this.title,
    required this.artist,
    required this.album,
    this.artwork,
    required this.plays,
    required this.totalListeningMs,
    required this.completions,
    required this.skips,
  });

  String get formattedDuration {
    final seconds = totalListeningMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// Statistics for a top-played album.
class TopAlbumStat {
  final String album;
  final String artist;
  final String? artwork;
  final int plays;
  final int totalListeningMs;

  const TopAlbumStat({
    required this.album,
    required this.artist,
    this.artwork,
    required this.plays,
    required this.totalListeningMs,
  });

  String get formattedListeningTime {
    final seconds = totalListeningMs ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// Statistics for a top-played folder.
class TopFolderStat {
  final String folder;
  final int plays;
  final int totalListeningMs;

  const TopFolderStat({
    required this.folder,
    required this.plays,
    required this.totalListeningMs,
  });

  String get folderName {
    if (folder.isEmpty || folder == '.') return 'Root Folder';
    return p.basename(folder);
  }

  String get formattedListeningTime {
    final seconds = totalListeningMs ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// Audio quality format distribution.
class QualityDistribution {
  final int hiResCount;
  final int cdQualityCount;
  final int lossyCount;

  const QualityDistribution({
    required this.hiResCount,
    required this.cdQualityCount,
    required this.lossyCount,
  });

  int get total => hiResCount + cdQualityCount + lossyCount;

  double get hiResRatio => total > 0 ? hiResCount / total : 0.0;
  double get cdRatio => total > 0 ? cdQualityCount / total : 0.0;
  double get lossyRatio => total > 0 ? lossyCount / total : 0.0;
}

/// Strictly local SQLite telemetry and analytics tracker.
///
/// Logs verified play counts, cumulative listening time, completion ratios vs. early skips,
/// top tracks, albums, and folders without any network calls.
class PlaybackTelemetryEngine {
  PlaybackTelemetryEngine._();
  static final PlaybackTelemetryEngine instance = PlaybackTelemetryEngine._();

  final _dbInit = sqlite.SingleFlightInitializer<Database>();
  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<PlaybackState>? _playbackStateSub;

  // Active tracking session state
  MediaItem? _currentTrack;
  DateTime? _sessionStart;
  int _accumulatedMs = 0;
  DateTime? _lastTickTime;
  bool _isPlaying = false;
  Duration _lastPosition = Duration.zero;

  static const String _tableName = 'playback_telemetry';
  static const int _dbVersion = 1;

  Future<Database> _open() => _dbInit.getOrCreate(
        () => sqlite.openAppDatabase(
          'playback_telemetry.db',
          version: _dbVersion,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS $_tableName (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                track_key TEXT NOT NULL,
                title TEXT NOT NULL,
                artist TEXT NOT NULL,
                album TEXT NOT NULL,
                folder TEXT NOT NULL,
                artwork TEXT,
                duration_ms INTEGER NOT NULL,
                listened_ms INTEGER NOT NULL,
                completed INTEGER NOT NULL,
                skipped INTEGER NOT NULL,
                bit_depth INTEGER,
                sample_rate INTEGER,
                bitrate INTEGER,
                format TEXT,
                output_route TEXT
              );
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetry_time ON $_tableName(timestamp);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetry_track ON $_tableName(track_key);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetry_album ON $_tableName(album);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_telemetry_folder ON $_tableName(folder);');
          },
          onUpgrade: (db, oldVersion, newVersion) async {},
        ),
      );

  /// Initializes the telemetry engine with [MusicPlayerRuntime].
  void init(MusicPlayerRuntime runtime) {
    _mediaItemSub?.cancel();
    _playbackStateSub?.cancel();

    _mediaItemSub = runtime.mediaItemEvents().listen(_onMediaItemChanged);
    _playbackStateSub = runtime.playbackStateEvents().listen(_onPlaybackStateChanged);
  }

  void dispose() {
    _finalizeActiveSession();
    _mediaItemSub?.cancel();
    _mediaItemSub = null;
    _playbackStateSub?.cancel();
    _playbackStateSub = null;
  }

  void _onMediaItemChanged(MediaItem? item) {
    if (_currentTrack?.id != item?.id) {
      _finalizeActiveSession();
      if (item != null) {
        _currentTrack = item;
        _sessionStart = DateTime.now();
        _accumulatedMs = 0;
        _lastTickTime = _isPlaying ? DateTime.now() : null;
        _lastPosition = Duration.zero;
      } else {
        _currentTrack = null;
      }
    }
  }

  void _onPlaybackStateChanged(PlaybackState state) {
    _lastPosition = state.position;
    final wasPlaying = _isPlaying;
    _isPlaying = state.playing;

    final now = DateTime.now();
    if (wasPlaying && _lastTickTime != null) {
      _accumulatedMs += now.difference(_lastTickTime!).inMilliseconds;
    }

    if (_isPlaying) {
      _lastTickTime = now;
    } else {
      _lastTickTime = null;
    }
  }

  void _finalizeActiveSession() {
    final track = _currentTrack;
    if (track == null || _sessionStart == null) return;

    final now = DateTime.now();
    if (_isPlaying && _lastTickTime != null) {
      _accumulatedMs += now.difference(_lastTickTime!).inMilliseconds;
      _lastTickTime = null;
    }

    final listenedMs = _accumulatedMs;
    final durationMs = track.duration?.inMilliseconds ?? 0;

    // Minimum 1.5 seconds to log an event
    if (listenedMs >= 1500) {
      // Determine completion vs. early skip
      final bool completed;
      final bool skipped;

      if (durationMs > 0) {
        final ratio = listenedMs / durationMs;
        if (ratio >= 0.80 || (durationMs - _lastPosition.inMilliseconds).abs() <= 4000) {
          completed = true;
          skipped = false;
        } else if (listenedMs < 30000 && ratio < 0.40) {
          completed = false;
          skipped = true;
        } else {
          completed = false;
          skipped = false;
        }
      } else {
        completed = listenedMs >= 30000;
        skipped = listenedMs < 15000;
      }

      unawaited(_recordEvent(
        track: track,
        durationMs: durationMs,
        listenedMs: listenedMs,
        completed: completed,
        skipped: skipped,
      ));
    }

    _currentTrack = null;
    _sessionStart = null;
    _accumulatedMs = 0;
  }

  Future<void> _recordEvent({
    required MediaItem track,
    required int durationMs,
    required int listenedMs,
    required bool completed,
    required bool skipped,
  }) async {
    try {
      final db = await _open();
      final source = track.extras?['source']?.toString() ?? '';
      final folder = source.isNotEmpty ? p.dirname(source) : '';
      final bitDepth = (track.extras?['bit_depth'] as num?)?.toInt();
      final sampleRate = (track.extras?['sample_rate'] as num?)?.toInt();
      final bitrate = (track.extras?['bitrate'] as num?)?.toInt();
      final format = track.extras?['format']?.toString() ??
          (source.isNotEmpty ? p.extension(source).replaceAll('.', '') : '');

      await db.insert(_tableName, {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'track_key': track.id,
        'title': track.title,
        'artist': track.artist ?? 'Unknown Artist',
        'album': track.album ?? 'Unknown Album',
        'folder': folder,
        'artwork': track.artUri?.toString(),
        'duration_ms': durationMs,
        'listened_ms': listenedMs,
        'completed': completed ? 1 : 0,
        'skipped': skipped ? 1 : 0,
        'bit_depth': bitDepth,
        'sample_rate': sampleRate,
        'bitrate': bitrate,
        'format': format.toUpperCase(),
        'output_route': 'Hardware DAC',
      });
    } catch (e) {
      debugPrint('PlaybackTelemetryEngine: Error recording event: $e');
    }
  }

  /// Returns overall listening telemetry for the given past [days] (or all time if null).
  Future<TelemetryOverview> getOverview({int? days}) async {
    final db = await _open();
    final where = days != null ? 'WHERE timestamp >= ?' : '';
    final args = days != null ? [DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch] : <Object>[];

    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(listened_ms), 0) AS total_listening,
        COUNT(CASE WHEN completed = 1 OR listened_ms >= 30000 THEN 1 END) AS verified_plays,
        COALESCE(SUM(completed), 0) AS total_completions,
        COALESCE(SUM(skipped), 0) AS total_skips,
        COUNT(DISTINCT track_key) AS total_tracks
      FROM $_tableName
      $where
    ''', args);

    if (rows.isEmpty) {
      return const TelemetryOverview(
        totalListeningMs: 0,
        totalPlays: 0,
        totalCompletions: 0,
        totalSkips: 0,
        totalTracks: 0,
      );
    }

    final row = rows.first;
    return TelemetryOverview(
      totalListeningMs: (row['total_listening'] as num?)?.toInt() ?? 0,
      totalPlays: (row['verified_plays'] as num?)?.toInt() ?? 0,
      totalCompletions: (row['total_completions'] as num?)?.toInt() ?? 0,
      totalSkips: (row['total_skips'] as num?)?.toInt() ?? 0,
      totalTracks: (row['total_tracks'] as num?)?.toInt() ?? 0,
    );
  }

  /// Returns top-played tracks ranked by play count and listening time.
  Future<List<TopTrackStat>> getTopTracks({int limit = 10, int? days}) async {
    final db = await _open();
    final where = days != null ? 'WHERE timestamp >= ?' : '';
    final args = days != null ? [DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch] : <Object>[];

    final rows = await db.rawQuery('''
      SELECT
        track_key,
        title,
        artist,
        album,
        artwork,
        COUNT(CASE WHEN completed = 1 OR listened_ms >= 30000 THEN 1 END) AS plays,
        SUM(listened_ms) AS total_listened,
        SUM(completed) AS completions,
        SUM(skipped) AS skips
      FROM $_tableName
      $where
      GROUP BY track_key
      ORDER BY plays DESC, total_listened DESC
      LIMIT $limit
    ''', args);

    return rows
        .map((row) => TopTrackStat(
              trackKey: row['track_key'] as String? ?? '',
              title: row['title'] as String? ?? 'Unknown Title',
              artist: row['artist'] as String? ?? 'Unknown Artist',
              album: row['album'] as String? ?? 'Unknown Album',
              artwork: row['artwork'] as String?,
              plays: (row['plays'] as num?)?.toInt() ?? 0,
              totalListeningMs: (row['total_listened'] as num?)?.toInt() ?? 0,
              completions: (row['completions'] as num?)?.toInt() ?? 0,
              skips: (row['skips'] as num?)?.toInt() ?? 0,
            ))
        .toList(growable: false);
  }

  /// Returns top-played albums ranked by listening time.
  Future<List<TopAlbumStat>> getTopAlbums({int limit = 10, int? days}) async {
    final db = await _open();
    final where = days != null ? 'WHERE timestamp >= ?' : '';
    final args = days != null ? [DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch] : <Object>[];

    final rows = await db.rawQuery('''
      SELECT
        album,
        artist,
        artwork,
        COUNT(CASE WHEN completed = 1 OR listened_ms >= 30000 THEN 1 END) AS plays,
        SUM(listened_ms) AS total_listened
      FROM $_tableName
      $where
      GROUP BY album, artist
      HAVING album != '' AND album != 'Unknown Album'
      ORDER BY total_listened DESC
      LIMIT $limit
    ''', args);

    return rows
        .map((row) => TopAlbumStat(
              album: row['album'] as String? ?? 'Unknown Album',
              artist: row['artist'] as String? ?? 'Unknown Artist',
              artwork: row['artwork'] as String?,
              plays: (row['plays'] as num?)?.toInt() ?? 0,
              totalListeningMs: (row['total_listened'] as num?)?.toInt() ?? 0,
            ))
        .toList(growable: false);
  }

  /// Returns top-played folders ranked by listening time.
  Future<List<TopFolderStat>> getTopFolders({int limit = 10, int? days}) async {
    final db = await _open();
    final where = days != null ? 'WHERE timestamp >= ?' : '';
    final args = days != null ? [DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch] : <Object>[];

    final rows = await db.rawQuery('''
      SELECT
        folder,
        COUNT(CASE WHEN completed = 1 OR listened_ms >= 30000 THEN 1 END) AS plays,
        SUM(listened_ms) AS total_listened
      FROM $_tableName
      $where
      GROUP BY folder
      HAVING folder != ''
      ORDER BY total_listened DESC
      LIMIT $limit
    ''', args);

    return rows
        .map((row) => TopFolderStat(
              folder: row['folder'] as String? ?? '',
              plays: (row['plays'] as num?)?.toInt() ?? 0,
              totalListeningMs: (row['total_listened'] as num?)?.toInt() ?? 0,
            ))
        .toList(growable: false);
  }

  /// Returns the distribution of audio quality (Hi-Res vs. CD vs. Lossy).
  Future<QualityDistribution> getQualityDistribution({int? days}) async {
    final db = await _open();
    final where = days != null ? 'WHERE timestamp >= ?' : '';
    final args = days != null ? [DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch] : <Object>[];

    final rows = await db.rawQuery('''
      SELECT
        COUNT(CASE WHEN (bit_depth >= 24 OR sample_rate >= 88200) THEN 1 END) AS hires_count,
        COUNT(CASE WHEN (bit_depth = 16 OR (sample_rate >= 44100 AND sample_rate < 88200))
                   AND (format IN ('FLAC', 'WAV', 'ALAC', 'AIFF') OR format LIKE '%FLAC%') THEN 1 END) AS cd_count,
        COUNT(CASE WHEN format IN ('MP3', 'AAC', 'OPUS', 'OGG', 'M4A') THEN 1 END) AS lossy_count
      FROM $_tableName
      $where
    ''', args);

    if (rows.isEmpty) {
      return const QualityDistribution(hiResCount: 0, cdQualityCount: 0, lossyCount: 0);
    }

    final row = rows.first;
    return QualityDistribution(
      hiResCount: (row['hires_count'] as num?)?.toInt() ?? 0,
      cdQualityCount: (row['cd_count'] as num?)?.toInt() ?? 0,
      lossyCount: (row['lossy_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Clears all local telemetry history.
  Future<void> clearTelemetry() async {
    final db = await _open();
    await db.delete(_tableName);
  }
}
