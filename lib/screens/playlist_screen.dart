import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/spotify_api.dart';
import '../widgets/bottom_player_bar.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late final SpotifyApi _api = SpotifyApi(context.read<AuthService>());
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _api.playlist(widget.playlistId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      bottomNavigationBar: const BottomPlayerBar(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final p = snap.data!;
          final images = (p['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final url = images.isNotEmpty ? images.first['url'] as String? : null;
          final tracks = ((p['tracks']?['items'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();
          return ListView(
            children: [
              if (url != null)
                CachedNetworkImage(imageUrl: url, height: 240, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'] as String? ?? '',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play playlist'),
                      onPressed: () => context
                          .read<PlayerService>()
                          .playContext('spotify:playlist:${widget.playlistId}'),
                    ),
                  ],
                ),
              ),
              ...tracks.map((item) {
                final t = item['track'] as Map<String, dynamic>? ?? {};
                final id = t['id'] as String?;
                final artists = ((t['artists'] as List?) ?? const [])
                    .cast<Map<String, dynamic>>()
                    .map((a) => a['name'])
                    .join(', ');
                return ListTile(
                  title: Text(t['name'] as String? ?? ''),
                  subtitle: Text(artists),
                  onTap: id == null
                      ? null
                      : () => context.read<PlayerService>().playTrack(id),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
