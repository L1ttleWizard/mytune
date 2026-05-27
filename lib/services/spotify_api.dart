import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'auth_service.dart';

/// Thin wrapper around Spotify Web API endpoints we use.
///
/// Every endpoint here works on a FREE Spotify account — no Premium needed.
class SpotifyApi {
  SpotifyApi(this._auth);

  final AuthService _auth;

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final token = await _auth.getValidAccessToken();
    final uri = Uri.parse('${AppConstants.spotifyApiBase}$path')
        .replace(queryParameters: query);
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (resp.statusCode != 200) {
      throw Exception('GET $path failed: ${resp.statusCode} ${resp.body}');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() => _get('/me');

  Future<Map<String, dynamic>> myPlaylists({int limit = 50}) =>
      _get('/me/playlists', {'limit': '$limit'});

  Future<Map<String, dynamic>> playlist(String id) => _get('/playlists/$id');

  Future<Map<String, dynamic>> playlistTracks(String id,
          {int limit = 100, int offset = 0}) =>
      _get('/playlists/$id/tracks', {
        'limit': '$limit',
        'offset': '$offset',
      });

  Future<Map<String, dynamic>> album(String id) => _get('/albums/$id');

  Future<Map<String, dynamic>> myTopTracks({int limit = 20}) =>
      _get('/me/top/tracks', {'limit': '$limit'});

  Future<Map<String, dynamic>> mySavedTracks(
          {int limit = 50, int offset = 0}) =>
      _get('/me/tracks', {'limit': '$limit', 'offset': '$offset'});

  Future<Map<String, dynamic>> newReleases({int limit = 20}) =>
      _get('/browse/new-releases', {'limit': '$limit'});

  Future<Map<String, dynamic>> search(String query,
          {List<String> types = const ['track', 'album', 'artist', 'playlist'],
          int limit = 20}) =>
      _get('/search', {
        'q': query,
        'type': types.join(','),
        'limit': '$limit',
      });
}
