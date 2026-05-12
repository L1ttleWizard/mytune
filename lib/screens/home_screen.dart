import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/spotify_api.dart';
import '../services/tab_switcher.dart';
import '../widgets/app_bottom_chrome.dart';
import '../widgets/hidden_player_webview.dart';
import 'library_screen.dart';
import 'playlist_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWebView = false;

  void _showDebugDialog(BuildContext context) {
    final player = context.read<PlayerService>();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final js = player.lastJsState;
        return AlertDialog(
          title: const Text('Player state'),
          content: SingleChildScrollView(
            child: Text(
              'webPlayerReady: ${player.webPlayerReady}\n'
              'hasTrack: ${player.state.hasTrack}\n'
              'isPlaying: ${player.state.isPlaying}\n'
              'trackId: ${player.state.trackId}\n'
              'title: ${player.state.title}\n'
              'artist: ${player.state.artist}\n'
              'artworkUrl: ${player.state.artworkUrl}\n'
              'pos/dur: ${player.state.position.inMilliseconds}/${player.state.duration.inMilliseconds} ms\n'
              '\nRaw JS:\n${const JsonEncoder.withIndent('  ').convert(js)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = context.watch<TabSwitcher>().index;
    final pages = [
      const _HomeTab(),
      const SearchScreen(),
      const LibraryScreen(),
    ];
    // The hidden web player lives behind the entire app so it survives
    // tab switches and keeps audio playing while the user browses.
    //
    // It must stay in the widget tree and be laid out (NOT `Offstage`)
    // — InAppWebView is a native Android view and only initialises when
    // it has a real size, and open.spotify.com refuses to render its
    // full player UI on tiny viewports. We always give it the entire
    // screen, then cover it with the visible UI so the user doesn't
    // see it. A debug toggle in the AppBar uncovers the WebView so we
    // can verify what Spotify actually shows inside.
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyTune'),
        actions: [
          IconButton(
            tooltip: 'Show player state (debug)',
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showDebugDialog(context),
          ),
          IconButton(
            tooltip: 'Toggle web player view (debug)',
            icon: Icon(_showWebView ? Icons.visibility_off : Icons.web),
            onPressed: () => setState(() => _showWebView = !_showWebView),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showWebView,
              child: const HiddenPlayerWebView(loginMode: false),
            ),
          ),
          if (!_showWebView)
            Positioned.fill(
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(child: pages[tabIndex]),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomChrome(),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late final SpotifyApi _api = SpotifyApi(context.read<AuthService>());
  Future<_HomeData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final playlists = await _api.myPlaylists(limit: 20);
    final top = await _api.myTopTracks(limit: 10);
    return _HomeData(
      playlists: ((playlists['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
      topTracks: ((top['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final data = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your playlists',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) => _PlaylistCard(data.playlists[i]),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: data.playlists.length,
              ),
            ),
            const SizedBox(height: 24),
            Text('Your top tracks',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...data.topTracks.map((t) => _TrackTile(t)),
          ],
        );
      },
    );
  }
}

class _HomeData {
  _HomeData({required this.playlists, required this.topTracks});
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> topTracks;
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard(this.p);
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final images = (p['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final url = images.isNotEmpty ? images.first['url'] as String? : null;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaylistScreen(playlistId: p['id'] as String),
        ),
      ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: url != null
                  ? CachedNetworkImage(
                      imageUrl: url, width: 140, height: 140, fit: BoxFit.cover)
                  : Container(width: 140, height: 140, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(p['name'] as String? ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile(this.t);
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final album = t['album'] as Map<String, dynamic>?;
    final images = (album?['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final url = images.isNotEmpty ? images.last['url'] as String? : null;
    final artists = ((t['artists'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((a) => a['name'])
        .join(', ');
    return ListTile(
      leading: url != null
          ? CachedNetworkImage(imageUrl: url, width: 48, height: 48)
          : const SizedBox(width: 48, height: 48),
      title: Text(t['name'] as String? ?? ''),
      subtitle: Text(artists, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => context.read<PlayerService>().playTrack(t['id'] as String),
    );
  }
}


