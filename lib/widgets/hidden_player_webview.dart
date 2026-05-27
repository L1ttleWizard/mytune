import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/player_service.dart';

/// Always-present WebView that runs open.spotify.com as the playback engine.
///
/// When [loginMode] is true the widget renders the WebView full-screen so the
/// user can complete Spotify's login flow; once playback is ready it shrinks
/// off-screen and is driven entirely through JS injection from PlayerService.
class HiddenPlayerWebView extends StatefulWidget {
  const HiddenPlayerWebView({
    super.key,
    required this.loginMode,
    this.onAuthCode,
    this.onLoggedIn,
  });

  final bool loginMode;
  final void Function(String code)? onAuthCode;
  final VoidCallback? onLoggedIn;

  @override
  State<HiddenPlayerWebView> createState() => _HiddenPlayerWebViewState();
}

class _HiddenPlayerWebViewState extends State<HiddenPlayerWebView> {
  WebUri? _initialUrl;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthService>();
    if (widget.loginMode && !auth.isLoggedIn) {
      final url = await auth.buildAuthorizeUrl();
      setState(() => _initialUrl = WebUri(url));
    } else {
      setState(() => _initialUrl = WebUri(AppConstants.spotifyWebPlayer));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialUrl == null) {
      return const SizedBox.shrink();
    }
    final player = context.read<PlayerService>();
    return InAppWebView(
      initialUrlRequest: URLRequest(url: _initialUrl),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        useShouldOverrideUrlLoading: true,
        userAgent: AppConstants.desktopUserAgent,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (controller) {
        player.attachController(controller);
        controller.addJavaScriptHandler(
          handlerName: 'playerState',
          callback: (args) {
            if (args.isEmpty) return;
            final raw = args.first;
            final map = raw is String
                ? jsonDecode(raw) as Map<String, dynamic>
                : raw as Map<String, dynamic>;
            player.updateFromJs(map);
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'webPlayerReady',
          callback: (_) => player.markWebPlayerReady(),
        );
      },
      // Critical for Spotify: the web player uses Widevine DRM to stream
      // audio. Without granting the PROTECTED_MEDIA_ID permission the page
      // shows "Playback of protected content is not enabled" and refuses
      // to play anything. We grant any permission the page asks for since
      // we trust open.spotify.com.
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      },
      shouldOverrideUrlLoading: (controller, navAction) async {
        final url = navAction.request.url?.toString() ?? '';
        if (url.startsWith(AppConstants.redirectUri)) {
          final uri = Uri.parse(url);
          final code = uri.queryParameters['code'];
          if (code != null) {
            widget.onAuthCode?.call(code);
          }
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onLoadStop: (controller, url) async {
        final href = url?.toString() ?? '';
        if (href.startsWith(AppConstants.spotifyWebPlayer)) {
          await _installStateBridge(controller);
          widget.onLoggedIn?.call();
        }
      },
    );
  }

  /// Injects a polling script that reports the current playback state back
  /// to Dart by calling `window.flutter_inappwebview.callHandler`.
  ///
  /// We treat the underlying `<audio>` element as the source of truth for
  /// play/pause and progress (`audio.paused` and `audio.currentTime`),
  /// because the DOM `data-testid` selectors Spotify uses change over time
  /// and don't always exist on every page. Track metadata comes from
  /// `navigator.mediaSession.metadata` when available, with DOM fallbacks.
  Future<void> _installStateBridge(InAppWebViewController c) async {
    await c.evaluateJavascript(source: r'''
      (function(){
        if (window.__mytuneBridge) {
          clearInterval(window.__mytuneBridge);
        }

        function pickArt(art) {
          if (!art || !art.length) return null;
          var best = art[0];
          for (var i = 1; i < art.length; i++) {
            if ((art[i].sizes || '').length > (best.sizes || '').length) best = art[i];
          }
          return best.src || null;
        }

        function textOf(sel) {
          var el = document.querySelector(sel);
          return el ? (el.textContent || '').trim() : null;
        }

        function parseTime(t) {
          if (!t) return null;
          var parts = t.split(':').map(function(x){ return parseInt(x, 10); });
          if (parts.some(isNaN)) return null;
          if (parts.length === 2) return (parts[0]*60 + parts[1]) * 1000;
          if (parts.length === 3) return (parts[0]*3600 + parts[1]*60 + parts[2]) * 1000;
          return null;
        }

        function findAudio() {
          // Spotify uses a normal <audio> element in the main document.
          // Search same-origin iframes as a fallback just in case.
          var a = document.querySelector('audio');
          if (a) return a;
          var iframes = document.querySelectorAll('iframe');
          for (var i = 0; i < iframes.length; i++) {
            try {
              var doc = iframes[i].contentDocument;
              if (doc) {
                var inner = doc.querySelector('audio');
                if (inner) return inner;
              }
            } catch (e) { /* cross-origin */ }
          }
          return null;
        }

        function readState() {
          var md = (navigator.mediaSession && navigator.mediaSession.metadata) || {};
          var audio = findAudio();

          // ----- isPlaying: combine three independent signals -----
          var isPlaying = false;
          if (audio && !audio.paused) isPlaying = true;
          var ps = navigator.mediaSession && navigator.mediaSession.playbackState;
          if (ps === 'playing') isPlaying = true;
          var ppBtn = document.querySelector('[data-testid="control-button-playpause"]');
          if (ppBtn) {
            var lbl = (ppBtn.getAttribute('aria-label') || '').toLowerCase().trim();
            if (lbl.indexOf('pause') === 0 || lbl.indexOf('пауза') === 0) {
              isPlaying = true;
            }
          }

          // ----- trackId -----
          var trackId = null;
          var nowPlayingLink = document.querySelector(
            '[data-testid="now-playing-widget"] a[href^="/track/"]'
          );
          if (nowPlayingLink) {
            var m = nowPlayingLink.getAttribute('href').match(/\/track\/([^/?]+)/);
            if (m) trackId = m[1];
          }
          if (!trackId) {
            var loc = location.pathname.match(/\/track\/([^/?]+)/);
            if (loc) trackId = loc[1];
          }

          // ----- title / artist -----
          var title = md.title;
          if (!title) {
            title = textOf('[data-testid="now-playing-widget"] [data-testid="context-item-link"]')
                  || textOf('[data-testid="context-item-info-title"]')
                  || textOf('[data-testid="now-playing-widget"] a[href^="/track/"]')
                  || textOf('main [data-testid="entityTitle"]');
          }
          var artist = md.artist;
          if (!artist) {
            artist = textOf('[data-testid="now-playing-widget"] [data-testid="context-item-info-subtitles"]')
                  || textOf('[data-testid="now-playing-widget"] a[href^="/artist/"]');
          }

          // ----- artwork -----
          var artworkUrl = pickArt(md.artwork);
          if (!artworkUrl) {
            var img = document.querySelector('[data-testid="now-playing-widget"] img')
                  || document.querySelector('[data-testid="cover-art-image"] img')
                  || document.querySelector('img[data-testid="cover-art-image"]');
            if (img && img.src) artworkUrl = img.src;
          }

          // ----- position / duration -----
          var positionMs = audio ? Math.floor(audio.currentTime * 1000) : null;
          var durationMs = audio && audio.duration && isFinite(audio.duration)
              ? Math.floor(audio.duration * 1000)
              : null;
          if (durationMs == null) {
            durationMs = parseTime(textOf('[data-testid="playback-duration"]'));
          }
          if (positionMs == null) {
            positionMs = parseTime(textOf('[data-testid="playback-position"]'));
          }

          return {
            trackId: trackId,
            title: title || null,
            artist: artist || null,
            album: md.album || null,
            artworkUrl: artworkUrl || null,
            isPlaying: isPlaying,
            positionMs: positionMs,
            durationMs: durationMs,
            // Diagnostic fields visible to the debug overlay.
            __debug: {
              hasAudio: !!audio,
              audioPaused: audio ? audio.paused : null,
              audioCurrentTime: audio ? audio.currentTime : null,
              audioDuration: audio ? audio.duration : null,
              mediaSessionPlaybackState: ps || null,
              ppBtnLabel: ppBtn ? ppBtn.getAttribute('aria-label') : null,
              url: location.href
            }
          };
        }

        function tick() {
          try {
            var s = readState();
            window.flutter_inappwebview.callHandler('playerState', s);
          } catch (e) { /* swallow */ }
        }

        window.__mytuneBridge = setInterval(tick, 750);
        window.flutter_inappwebview.callHandler('webPlayerReady', {});
      })();
    ''');
  }
}
