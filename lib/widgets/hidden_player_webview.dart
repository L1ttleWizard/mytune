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
  /// We watch `navigator.mediaSession.metadata` (Spotify sets it whenever a
  /// track starts), plus the audio element for play/pause and progress, and
  /// the now-playing widget DOM for fallback metadata.
  Future<void> _installStateBridge(InAppWebViewController c) async {
    await c.evaluateJavascript(source: r'''
      (function(){
        if (window.__mytuneBridgeInstalled) return;
        window.__mytuneBridgeInstalled = true;

        function pickArt(art) {
          if (!art || !art.length) return null;
          var best = art[0];
          for (var i = 1; i < art.length; i++) {
            if ((art[i].sizes || '').length > (best.sizes || '').length) best = art[i];
          }
          return best.src || null;
        }

        function readState() {
          var md = (navigator.mediaSession && navigator.mediaSession.metadata) || {};
          var audio = document.querySelector('audio');
          var nowPlayingLink = document.querySelector(
            '[data-testid="now-playing-widget"] a[href^="/track/"]'
          );
          var trackId = null;
          if (nowPlayingLink) {
            var m = nowPlayingLink.getAttribute('href').match(/\/track\/([^/?]+)/);
            if (m) trackId = m[1];
          }
          var playBtn = document.querySelector('[data-testid="control-button-playpause"]');
          var label = (playBtn && playBtn.getAttribute('aria-label') || '').toLowerCase();
          var isPlaying = !!playBtn && (label.indexOf('pause') === 0 || label.indexOf('пауза') === 0);
          return {
            trackId: trackId,
            title: md.title || null,
            artist: md.artist || null,
            album: md.album || null,
            artworkUrl: pickArt(md.artwork),
            isPlaying: isPlaying,
            positionMs: audio ? Math.floor(audio.currentTime * 1000) : null,
            durationMs: audio ? Math.floor((audio.duration || 0) * 1000) : null
          };
        }

        function tick() {
          try {
            var s = readState();
            window.flutter_inappwebview.callHandler('playerState', s);
          } catch (e) { /* swallow */ }
        }

        setInterval(tick, 750);
        window.flutter_inappwebview.callHandler('webPlayerReady', {});
      })();
    ''');
  }
}
