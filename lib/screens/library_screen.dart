import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/spotify_api.dart';
import 'liked_songs_screen.dart';
import 'playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final SpotifyApi _api = SpotifyApi(context.read<AuthService>());
  Future<_LibraryData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LibraryData> _load() async {
    final playlists = await _api.myPlaylists(limit: 50);
    final saved = await _api.mySavedTracks(limit: 50);
    return _LibraryData(
      playlists: ((playlists['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
      savedTracks: ((saved['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Playlists'),
              Tab(text: 'Liked songs'),
            ],
          ),
          Expanded(
            child: FutureBuilder<_LibraryData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final data = snap.data!;
                return TabBarView(
                  children: [
                    _PlaylistList(data.playlists),
                    _SavedTracksList(data.savedTracks),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryData {
  _LibraryData({required this.playlists, required this.savedTracks});
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> savedTracks;
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList(this.playlists);
  final List<Map<String, dynamic>> playlists;

  @override
  Widget build(BuildContext context) {
    // +1 because we prepend a synthetic "Liked Songs" tile at index 0.
    return ListView.builder(
      itemCount: playlists.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purpleAccent.shade400,
                    Colors.white.withOpacity(0.1),
                  ],
                ),
              ),
              child: const Icon(Icons.favorite, color: Colors.white),
            ),
            title: const Text('Liked Songs'),
            subtitle: const Text('Your saved tracks'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LikedSongsScreen(),
              ),
            ),
          );
        }
        final p = playlists[i - 1];
        final images = (p['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final url = images.isNotEmpty ? images.last['url'] as String? : null;
        return ListTile(
          leading: url != null
              ? CachedNetworkImage(imageUrl: url, width: 56, height: 56)
              : const SizedBox(width: 56, height: 56),
          title: Text(p['name'] as String? ?? ''),
          subtitle: Text(
            ((p['owner'] as Map<String, dynamic>?)?['display_name'] as String?) ??
                '',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaylistScreen(playlistId: p['id'] as String),
            ),
          ),
        );
      },
    );
  }
}

class _SavedTracksList extends StatelessWidget {
  const _SavedTracksList(this.items);
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final t = items[i]['track'] as Map<String, dynamic>? ?? {};
        final album = t['album'] as Map<String, dynamic>?;
        final images =
            (album?['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final url = images.isNotEmpty ? images.last['url'] as String? : null;
        final artists = ((t['artists'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((a) => a['name'])
            .join(', ');
        final id = t['id'] as String?;
        return ListTile(
          leading: url != null
              ? CachedNetworkImage(imageUrl: url, width: 48, height: 48)
              : const SizedBox(width: 48, height: 48),
          title: Text(t['name'] as String? ?? ''),
          subtitle: Text(artists),
          onTap: id == null
              ? null
              : () => context.read<PlayerService>().playTrack(id),
        );
      },
    );
  }
}
