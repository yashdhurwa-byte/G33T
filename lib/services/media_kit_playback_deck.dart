import 'dart:async';
import 'package:mornye/services/playback_deck.dart';

/// MediaKit deck stubbed out for Android arm64 lean architecture.
/// Android uses AudioplayersPlaybackDeck and Oboe/USB DAC pipelines.
class MediaKitPlaybackDeck implements PlaybackDeck {
  MediaKitPlaybackDeck({required this.playerId});

  final String playerId;
  static bool get isAvailable => false;

  @override
  PlaybackDeckState get state => PlaybackDeckState.stopped;

  @override
  bool get isDirect => false;

  @override
  bool get needsSourceReload => false;

  @override
  Stream<PlaybackDeckState> get onPlayerStateChanged => const Stream.empty();

  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();

  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();

  @override
  Stream<void> get onPlayerComplete => const Stream.empty();

  @override
  void startPositionUpdates(Duration interval, {bool Function()? wanted}) {}

  @override
  Future<void> configureOutput() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setNetworkSource(String url, {bool arriving = false}) async {}

  @override
  Future<void> setFileSource(
    String path, {
    bool preferBitPerfect = false,
    bool directUsb = false,
    bool allowDop = false,
    bool requiresDsd = false,
    bool allowFixedVolume = false,
    bool dapExclusive = false,
  }) async {}

  @override
  Future<void> cancelPreparation() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> setNextDeck(PlaybackDeck? next) async => false;

  @override
  Future<Duration?> getCurrentPosition() async => Duration.zero;

  @override
  Future<Duration?> getDuration() async => Duration.zero;

  @override
  Future<void> dispose() async {}
}
