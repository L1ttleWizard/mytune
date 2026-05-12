import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/spotify_api.dart';
import '../widgets/bottom_player_bar.dart';
import '../widgets/hidden_player_webview.dart';
import 'playlist_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const SearchScreen(),
      const _LibraryTab(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          // The hidden web player lives behind the entire app so it survives
          // tab switches and keeps audio playing while the user browses.
          const Offstage(
            offstage: true,
            child: SizedBox(
              width: 1,
              height: 1,
              child: HiddenPlayerWebView(loginMode: false),
            ),
          ),
          SafeArea(child: pages[_tab]),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomPlayerBar(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
              NavigationDestination(
                  icon: Icon(Icons.library_music), label: 'Library'),
            ],
          ),
        ],
      ),
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

class _LibraryTab extends StatelessWidget {
  const _LibraryTab();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Library coming soon.\nThis prototype focuses on Home + Search + Playlist.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
