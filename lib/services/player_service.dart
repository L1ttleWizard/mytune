import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Snapshot of what the underlying Spotify web player is doing right now.
class PlayerState {
  PlayerState({
    this.trackId,
    this.title,
    this.artist,
    this.album,
    this.artworkUrl,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final String? trackId;
  final String? title;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  bool get hasTrack => trackId != null;

  PlayerState copyWith({
    String? trackId,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) =>
      PlayerState(
        trackId: trackId ?? this.trackId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
}

/// Controls the hidden WebView running open.spotify.com.
///
/// Commands are sent via JS injection that targets the data-testid hooks
/// the web player exposes; state updates come back through a JS handler
/// channel that polls navigator.mediaSession and DOM scrubber values.
class PlayerService extends ChangeNotifier {
  InAppWebViewController? _controller;
  PlayerState _state = PlayerState();
  bool _webPlayerReady = false;

  PlayerState get state => _state;
  bool get webPlayerReady => _webPlayerReady;

  void attachController(InAppWebViewController controller) {
    _controller = controller;
  }

  void markWebPlayerReady() {
    _webPlayerReady = true;
    notifyListeners();
  }

  void updateFromJs(Map<String, dynamic> data) {
    _state = _state.copyWith(
      trackId: data['trackId'] as String?,
      title: data['title'] as String?,
      artist: data['artist'] as String?,
      album: data['album'] as String?,
      artworkUrl: data['artworkUrl'] as String?,
      isPlaying: data['isPlaying'] as bool? ?? _state.isPlaying,
      position: Duration(
          milliseconds: (data['positionMs'] as num?)?.toInt() ??
              _state.position.inMilliseconds),
      duration: Duration(
          milliseconds: (data['durationMs'] as num?)?.toInt() ??
              _state.duration.inMilliseconds),
    );
    notifyListeners();
  }

  /// Load a track by Spotify ID and start playback.
  ///
  /// We navigate the web player to the track URL. open.spotify.com handles
  /// the actual streaming, ads, and DRM — we just point it at the right URL.
  Future<void> playTrack(String trackId) async {
    await _navigateAndAutoplay('https://open.spotify.com/track/$trackId');
  }

  Future<void> playContext(String contextUri) async {
    // contextUri examples: spotify:playlist:ID, spotify:album:ID
    // open.spotify.com paths use /playlist/ID, /album/ID.
    final parts = contextUri.split(':');
    if (parts.length < 3) return;
    await _navigateAndAutoplay(
        'https://open.spotify.com/${parts[1]}/${parts[2]}');
  }

  Future<void> _navigateAndAutoplay(String url) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    // The web player UI takes a variable amount of time to render after
    // navigation. Retry clicking the play button a few times so we don't
    // miss the window when it becomes available.
    for (final delay in const [
      Duration(milliseconds: 1500),
      Duration(milliseconds: 2500),
      Duration(milliseconds: 4000),
      Duration(milliseconds: 6000),
    ]) {
      Future.delayed(delay, _clickPlayIfPaused);
    }
  }

  Future<void> togglePlay() async {
    await _controller?.evaluateJavascript(source: _jsClick('control-button-playpause'));
  }

  Future<void> next() async {
    await _controller?.evaluateJavascript(source: _jsClick('control-button-skip-forward'));
  }

  Future<void> previous() async {
    await _controller?.evaluateJavascript(source: _jsClick('control-button-skip-back'));
  }

  Future<void> _clickPlayIfPaused() async {
    await _controller?.evaluateJavascript(source: '''
      (function(){
        var btn = document.querySelector('[data-testid="control-button-playpause"]');
        if (!btn) return;
        // If aria-label contains "Play" we're paused, click to start.
        var label = (btn.getAttribute('aria-label') || '').toLowerCase();
        if (label.indexOf('play') === 0 || label.indexOf('воспроизвести') === 0) {
          btn.click();
        }
      })();
    ''');
  }

  String _jsClick(String testid) => '''
    (function(){
      var btn = document.querySelector('[data-testid="$testid"]');
      if (btn) btn.click();
    })();
  ''';
}
