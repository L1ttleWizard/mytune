import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../services/auth_service.dart';
import '../widgets/hidden_player_webview.dart';
import 'home_screen.dart';

/// Hosts the visible WebView during Spotify login. Once the OAuth redirect
/// fires we exchange the code for tokens and continue to the home screen,
/// while the same WebView (now signed in via shared cookies) keeps running
/// behind the rest of the UI as the playback engine.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _exchanging = false;
  String? _error;

  Future<void> _onCode(String code) async {
    if (_exchanging) return;
    setState(() {
      _exchanging = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.exchangeCode(code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() {
        _exchanging = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const clientIdMissing =
        AppConstants.spotifyClientId == 'REPLACE_ME_WITH_YOUR_SPOTIFY_CLIENT_ID';
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (clientIdMissing)
              const _MissingClientIdHint()
            else
              HiddenPlayerWebView(
                loginMode: true,
                onAuthCode: _onCode,
              ),
            if (_exchanging)
              const ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MissingClientIdHint extends StatelessWidget {
  const _MissingClientIdHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_off, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Spotify Client ID is not configured.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Create an app at developer.spotify.com/dashboard, add\n'
              'mytune://callback as a Redirect URI, then rebuild with:\n\n'
              '  flutter run --dart-define=SPOTIFY_CLIENT_ID=<your-id>',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
