import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

/// OAuth 2.0 Authorization Code Flow with PKCE for Spotify Web API.
///
/// No Premium required; only reads metadata and the user's library.
class AuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'spotify_access_token';
  static const _kRefreshToken = 'spotify_refresh_token';
  static const _kExpiresAt = 'spotify_expires_at';
  static const _kVerifier = 'spotify_pkce_verifier';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null;

  Future<void> load() async {
    _accessToken = await _storage.read(key: _kAccessToken);
    _refreshToken = await _storage.read(key: _kRefreshToken);
    final exp = await _storage.read(key: _kExpiresAt);
    _expiresAt = exp == null ? null : DateTime.tryParse(exp);
    notifyListeners();
  }

  /// Build the authorize URL the WebView should navigate to.
  Future<String> buildAuthorizeUrl() async {
    final verifier = _generateCodeVerifier();
    await _storage.write(key: _kVerifier, value: verifier);
    final challenge = _codeChallenge(verifier);
    final params = {
      'client_id': AppConstants.spotifyClientId,
      'response_type': 'code',
      'redirect_uri': AppConstants.redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': AppConstants.scopes.join(' '),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '${AppConstants.spotifyAuthBase}/authorize?$query';
  }

  /// Exchange the authorization code (from redirect) for tokens.
  Future<void> exchangeCode(String code) async {
    final verifier = await _storage.read(key: _kVerifier);
    if (verifier == null) {
      throw StateError('PKCE verifier missing — call buildAuthorizeUrl first.');
    }
    final resp = await http.post(
      Uri.parse('${AppConstants.spotifyAuthBase}/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': AppConstants.redirectUri,
        'client_id': AppConstants.spotifyClientId,
        'code_verifier': verifier,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Token exchange failed: ${resp.statusCode} ${resp.body}');
    }
    await _saveTokenResponse(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Returns a fresh access token, refreshing if needed.
  Future<String> getValidAccessToken() async {
    if (_accessToken == null) {
      throw StateError('Not logged in.');
    }
    if (_expiresAt != null &&
        DateTime.now().isAfter(_expiresAt!.subtract(const Duration(minutes: 1)))) {
      await _refresh();
    }
    return _accessToken!;
  }

  Future<void> _refresh() async {
    if (_refreshToken == null) {
      throw StateError('No refresh token.');
    }
    final resp = await http.post(
      Uri.parse('${AppConstants.spotifyAuthBase}/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
        'client_id': AppConstants.spotifyClientId,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Refresh failed: ${resp.statusCode} ${resp.body}');
    }
    await _saveTokenResponse(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> _saveTokenResponse(Map<String, dynamic> data) async {
    _accessToken = data['access_token'] as String;
    final refresh = data['refresh_token'] as String?;
    if (refresh != null) _refreshToken = refresh;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await _storage.write(key: _kAccessToken, value: _accessToken);
    if (_refreshToken != null) {
      await _storage.write(key: _kRefreshToken, value: _refreshToken);
    }
    await _storage.write(key: _kExpiresAt, value: _expiresAt!.toIso8601String());
    notifyListeners();
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    await _storage.deleteAll();
    notifyListeners();
  }

  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(64, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _codeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
