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

  /// Custom URL scheme registered as a Spotify redirect URI in the dashboard.
  static const String redirectUri = 'mytune://callback';

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
