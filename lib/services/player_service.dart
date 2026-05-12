import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  bool get hasTrack => trackId != null || title != null;

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
  /// Method channel into the native PlaybackService that keeps the app
  /// process alive while audio is playing in the background.
  static const MethodChannel _serviceChannel =
      MethodChannel('mytune/playback_service');

  InAppWebViewController? _controller;
  PlayerState _state = PlayerState();
  bool _webPlayerReady = false;
  bool _serviceRunning = false;
  Map<String, dynamic> _lastJsState = const {};

  /// Last raw JS payload from the bridge. Exposed for the debug overlay.
  Map<String, dynamic> get lastJsState => _lastJsState;

  // Debounce: ignore back-to-back navigation requests so a user tapping
  // a track several times in a row doesn't trigger multiple WebView
  // navigations (and thus multiple playback starts).
  DateTime _lastNavAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastNavUrl;
  static const Duration _navDebounce = Duration(milliseconds: 700);

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
    _lastJsState = data;
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
    // Keep the foreground service in sync with actual playback state so
    // Android doesn't kill the process while audio is playing.
    if (_state.isPlaying) {
      _startServiceIfNeeded();
    } else {
      _stopServiceIfNeeded();
    }
    notifyListeners();
  }

  Future<void> _startServiceIfNeeded() async {
    if (_serviceRunning) return;
    _serviceRunning = true;
    try {
      await _serviceChannel.invokeMethod('start');
    } catch (_) {
      _serviceRunning = false;
    }
  }

  Future<void> _stopServiceIfNeeded() async {
    if (!_serviceRunning) return;
    _serviceRunning = false;
    try {
      await _serviceChannel.invokeMethod('stop');
    } catch (_) {
      // ignore
    }
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
    final now = DateTime.now();
    if (_lastNavUrl == url &&
        now.difference(_lastNavAt) < _navDebounce) {
      // Same destination within the debounce window — ignore.
      return;
    }
    _lastNavUrl = url;
    _lastNavAt = now;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    // Install a MutationObserver that clicks the play button the moment
    // it appears in the DOM, then disconnects. This avoids waiting for
    // arbitrary fixed delays and makes playback start as soon as Spotify
    // is ready to accept a click.
    await Future.delayed(const Duration(milliseconds: 200));
    await controller.evaluateJavascript(source: r'''
      (function(){
        // Reset on every navigation so the new page starts fresh.
        window.__mytuneAutoplayActive = true;

        var SELECTORS = [
          '[data-testid="control-button-playpause"]',
          '[data-testid="play-button"]',
          'button[aria-label^="Play"]',
          'button[aria-label^="play"]',
          'button[aria-label^="Воспроизвести"]'
        ];

        // Strict: aria-label must START with "play" (matches "Play",
        // "Play Mr. Brightside", etc.) and must NOT start with "playlist"
        // (the side-nav playlist links also have play-prefixed labels).
        function looksLikePlay(el) {
          if (!el) return false;
          var label = ((el.getAttribute('aria-label') || '') + '').toLowerCase().trim();
          if (!label) return false;
          if (label.indexOf('playlist') === 0) return false;
          return label.indexOf('play') === 0
                || label.indexOf('воспроизвести') === 0;
        }

        function alreadyPlaying() {
          var a = document.querySelector('audio');
          return !!(a && !a.paused && a.currentTime > 0);
        }

        function tryClick() {
          if (!window.__mytuneAutoplayActive) return false;
          if (alreadyPlaying()) {
            // Don't double-click — we'd just toggle pause / restart.
            window.__mytuneAutoplayActive = false;
            return true;
          }
          for (var i = 0; i < SELECTORS.length; i++) {
            var nodes = document.querySelectorAll(SELECTORS[i]);
            for (var j = 0; j < nodes.length; j++) {
              if (looksLikePlay(nodes[j])) {
                nodes[j].click();
                window.__mytuneAutoplayActive = false;
                return true;
              }
            }
          }
          return false;
        }

        if (tryClick()) return;

        var attempts = 0;
        var maxAttempts = 80; // ~8 seconds at 100ms intervals
        var poll = setInterval(function(){
          attempts++;
          if (tryClick() || attempts >= maxAttempts) {
            clearInterval(poll);
            window.__mytuneAutoplayActive = false;
          }
        }, 100);
      })();
    ''');
  }

  /// Seek to a position by setting the underlying <audio> element's
  /// currentTime directly inside the web player.
  Future<void> seek(Duration position) async {
    final ms = position.inMilliseconds;
    await _controller?.evaluateJavascript(source: '''
      (function(){
        var a = document.querySelector('audio');
        if (a) a.currentTime = ${ms / 1000.0};
      })();
    ''');
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

  String _jsClick(String testid) => '''
    (function(){
      var btn = document.querySelector('[data-testid="$testid"]');
      if (btn) btn.click();
    })();
  ''';
}
