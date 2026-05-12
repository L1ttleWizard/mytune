/// Application-wide constants.
///
/// IMPORTANT: Set [spotifyClientId] to your own Spotify Developer app
/// Client ID before running. Get one at https://developer.spotify.com/dashboard.
/// PKCE is used, so no client secret is required.
class AppConstants {
  /// Spotify Web API Client ID — replace with your own.
  static const String spotifyClientId =
      String.fromEnvironment('SPOTIFY_CLIENT_ID',
          defaultValue: 'REPLACE_ME_WITH_YOUR_SPOTIFY_CLIENT_ID');

  /// Redirect URI registered in the Spotify dashboard.
  ///
  /// Spotify tightened Redirect URI validation in late 2024 and custom
  /// schemes (e.g. `mytune://callback`) are no longer reliably accepted
  /// for new apps. We use an HTTPS URL instead and rely on the WebView's
  /// `shouldOverrideUrlLoading` to intercept the redirect before any real
  /// browser navigation happens, so the URL itself never has to resolve.
  ///
  /// You can override this at build time with
  /// `--dart-define=SPOTIFY_REDIRECT_URI=https://...` if you've registered
  /// a different URI in your Spotify app.
  static const String redirectUri = String.fromEnvironment(
    'SPOTIFY_REDIRECT_URI',
    defaultValue: 'https://example.com',
  );

  /// Scopes for Spotify Web API. None of these require Premium.
  static const List<String> scopes = [
    'user-read-private',
    'user-read-email',
    'playlist-read-private',
    'playlist-read-collaborative',
    'user-library-read',
    'user-top-read',
    'user-read-recently-played',
    'user-follow-read',
  ];

  static const String spotifyAuthBase = 'https://accounts.spotify.com';
  static const String spotifyApiBase = 'https://api.spotify.com/v1';
  static const String spotifyWebPlayer = 'https://open.spotify.com';

  /// Desktop UA so Spotify serves the full web player instead of a mobile
  /// "download the app" page.
  static const String desktopUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';
}
