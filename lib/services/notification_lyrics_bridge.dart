import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:mornye/services/player_widget_service.dart';
import 'package:mornye/utils/lyrics_parser.dart';
import 'package:mornye/utils/vorbis_metadata_utils.dart';

/// Bridges synchronized lyrics directly into Android's MediaSession / notification
/// metadata pipeline so live lyric lines stream to the system notification and One UI lock screen.
class NotificationLyricsBridge {
  NotificationLyricsBridge._();
  static final NotificationLyricsBridge instance = NotificationLyricsBridge._();

  BaseAudioHandler? _playerService;
  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<PlaybackState>? _playbackStateSub;
  Timer? _tickerTimer;

  bool _enabled = true;
  MediaItem? _lastHandledItem;
  String? _originalArtist;
  String? _originalDisplaySubtitle;
  String? _originalDisplayDescription;
  ParsedLyrics? _parsedLyrics;
  String? _lastEmittedLyric;
  bool _isEmittingNotification = false;

  bool get isEnabled => _enabled;
  String? get currentLyric => _lastEmittedLyric;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _revertMetadata();
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  /// Initializes the bridge with the active [BaseAudioHandler].
  void init(BaseAudioHandler playerService) {
    if (_playerService == playerService) return;
    dispose();
    _playerService = playerService;

    _mediaItemSub = playerService.mediaItem.listen(_onMediaItemChanged);
    _playbackStateSub = playerService.playbackState.listen(_onPlaybackStateChanged);
  }

  void dispose() {
    _mediaItemSub?.cancel();
    _mediaItemSub = null;
    _playbackStateSub?.cancel();
    _playbackStateSub = null;
    _stopTimer();
    _revertMetadata();
    _playerService = null;
  }

  Future<void> _onMediaItemChanged(MediaItem? item) async {
    if (_isEmittingNotification) return;

    if (item == null) {
      _lastHandledItem = null;
      _originalArtist = null;
      _originalDisplaySubtitle = null;
      _originalDisplayDescription = null;
      _parsedLyrics = null;
      _lastEmittedLyric = null;
      _stopTimer();
      return;
    }

    // New track started
    if (_lastHandledItem?.id != item.id) {
      _lastHandledItem = item;
      _originalArtist = item.extras?['originalArtist'] as String? ?? item.artist;
      _originalDisplaySubtitle = item.displaySubtitle;
      _originalDisplayDescription = item.displayDescription;
      _lastEmittedLyric = null;
      _parsedLyrics = null;

      await _loadLyricsForTrack(item);
    }
  }

  Future<void> _loadLyricsForTrack(MediaItem item) async {
    try {
      final source = item.extras?['source']?.toString() ??
          item.extras?['resolvedSource']?.toString() ??
          '';

      String? rawLyrics;

      // 1. Check if lyrics already in extras
      if (item.extras?['lyrics'] != null &&
          item.extras!['lyrics'].toString().trim().isNotEmpty) {
        rawLyrics = item.extras!['lyrics'].toString().trim();
      }

      // 2. Discover via offline Vorbis comment / sidecar .lrc
      if (rawLyrics == null && source.isNotEmpty) {
        rawLyrics = await VorbisLyricsExporter.findOfflineLyrics(source);
      }

      if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
        _parsedLyrics = await LyricsParser.parseAsyncNative(rawLyrics);
      }
    } catch (e) {
      debugPrint('NotificationLyricsBridge: Lyrics loading error: $e');
    }
  }

  void _onPlaybackStateChanged(PlaybackState state) {
    if (!_enabled) return;

    if (state.playing && _parsedLyrics != null && _parsedLyrics!.lines.isNotEmpty) {
      _startTimer();
    } else {
      _stopTimer();
      if (!state.playing) {
        _revertMetadata();
      }
    }
  }

  void _startTimer() {
    if (_tickerTimer != null && _tickerTimer!.isActive) return;
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 350), (_) => _tick());
  }

  void _stopTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  void _tick() {
    final service = _playerService;
    final item = _lastHandledItem;
    final lyrics = _parsedLyrics;

    if (!_enabled || service == null || item == null || lyrics == null || lyrics.lines.isEmpty) {
      return;
    }

    final state = service.playbackState.value;
    if (!state.playing) return;

    final position = state.position;
    final activeLine = _findActiveLine(lyrics.lines, position);

    if (activeLine == null || activeLine.text.trim().isEmpty) {
      if (_lastEmittedLyric != null) {
        _revertMetadata();
      }
      return;
    }

    final lyricText = activeLine.text.trim();
    if (lyricText == _lastEmittedLyric) return;

    _lastEmittedLyric = lyricText;
    _isEmittingNotification = true;

    try {
      final baseArtist = _originalArtist ?? '';
      // Samsung One UI and Android lock screen ticker format
      final formattedArtist = baseArtist.isNotEmpty
          ? '$baseArtist • $lyricText'
          : lyricText;

      final updated = item.copyWith(
        artist: formattedArtist,
        displaySubtitle: lyricText,
        displayDescription: lyricText,
        extras: {
          ...?item.extras,
          'originalArtist': _originalArtist,
          'notificationLyric': lyricText,
        },
      );

      service.mediaItem.add(updated);
      unawaited(PlayerWidgetService.instance.publish(force: true));
    } finally {
      _isEmittingNotification = false;
    }
  }

  LyricLine? _findActiveLine(List<LyricLine> lines, Duration position) {
    LyricLine? candidate;
    for (final line in lines) {
      if (line.time <= position) {
        if (line.end != null && position > line.end!) {
          continue;
        }
        candidate = line;
      } else {
        break;
      }
    }
    return candidate;
  }

  void _revertMetadata() {
    final service = _playerService;
    final item = _lastHandledItem;
    if (service == null || item == null || _lastEmittedLyric == null) return;

    _lastEmittedLyric = null;
    _isEmittingNotification = true;
    try {
      final reverted = item.copyWith(
        artist: _originalArtist,
        displaySubtitle: _originalDisplaySubtitle,
        displayDescription: _originalDisplayDescription,
        extras: {
          ...?item.extras,
          'notificationLyric': null,
        },
      );
      service.mediaItem.add(reverted);
      unawaited(PlayerWidgetService.instance.publish(force: true));
    } finally {
      _isEmittingNotification = false;
    }
  }
}
