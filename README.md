# MyTune

Custom Android Spotify client. Native Flutter UI on top, the actual
playback engine is `open.spotify.com` running inside a hidden WebView —
which means **a Spotify free account is enough**, no Premium required.

## How it works

- **Spotify Web API** (search, playlists, metadata, library) is used
  through standard OAuth Authorization Code + PKCE. None of these
  endpoints require Premium.
- **Playback** is driven by a hidden `flutter_inappwebview` instance
  pointed at `https://open.spotify.com`. Dart sends commands to the web
  player via JavaScript injection (clicking the same DOM controls a
  human would), and reads the current track / position back through a
  JS bridge that polls `navigator.mediaSession` and the audio element.
- The visible WebView used during login is the **same** WebView that
  later becomes the playback engine — Spotify's cookies are reused, so
  the user logs in only once.

## Setup

1. Install Flutter 3.24+ and the Android SDK.
2. Register an application at
   <https://developer.spotify.com/dashboard>:
   - Add `mytune://callback` as a Redirect URI.
   - Enable **Web API**.
   - Copy the Client ID.
3. Run:

   ```bash
   flutter pub get
   flutter run --dart-define=SPOTIFY_CLIENT_ID=<your-client-id>
   ```

   Or for a release-ish debug APK:

   ```bash
   flutter build apk --debug --dart-define=SPOTIFY_CLIENT_ID=<your-client-id>
   ```

## Project layout

```
lib/
├── main.dart                          App root, providers, theme
├── core/constants.dart                Spotify IDs, scopes, URLs
├── services/
│   ├── auth_service.dart              OAuth PKCE token lifecycle
│   ├── spotify_api.dart               Thin Web API client
│   └── player_service.dart            JS-injection playback control
├── widgets/
│   ├── hidden_player_webview.dart     open.spotify.com host + JS bridge
│   └── bottom_player_bar.dart         Mini player at the bottom
└── screens/
    ├── login_screen.dart              Visible WebView during OAuth
    ├── home_screen.dart               Playlists + top tracks
    ├── search_screen.dart             Web API search
    └── playlist_screen.dart           Single-playlist view
```

## Known limitations

- This is an MVP prototype. Library, queue, lyrics, downloads, and
  many other Spotify features are not yet implemented.
- Free-account restrictions still apply at the Spotify backend: ads,
  shuffle/skip limits, region locks.
- DOM selectors used in `player_service.dart` and
  `hidden_player_webview.dart` may drift if Spotify redesigns the web
  player; expect to update the `data-testid` strings.
- Google Play will not accept this app — distribute via direct APK or
  side-load.

## Legal

Reverse-engineering and automating `open.spotify.com` is against
Spotify's Terms of Service. This repository is published for personal,
educational use only. Use at your own risk; Spotify can ban accounts
that access their services through unofficial clients.
