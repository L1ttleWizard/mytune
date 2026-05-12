import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/spotify_api.dart';
import '../widgets/bottom_player_bar.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  late final SpotifyApi _api = SpotifyApi(context.read<AuthService>());
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await _api.mySavedTracks(limit: 50);
    return ((res['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liked Songs')),
      bottomNavigationBar: const BottomPlayerBar(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final items = snap.data!;
          return ListView(
            children: [
              Container(
                height: 200,
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
                child: const Center(
                  child: Icon(Icons.favorite, size: 80, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Liked Songs',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text('${items.length} tracks',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              final firstId = (items.first['track']
                                  as Map<String, dynamic>?)?['id'] as String?;
                              if (firstId != null) {
                                context.read<PlayerService>().playTrack(firstId);
                              }
                            },
                    ),
                  ],
                ),
              ),
              ...items.map((item) {
                final t = item['track'] as Map<String, dynamic>? ?? {};
                final album = t['album'] as Map<String, dynamic>?;
                final images = (album?['images'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                final url = images.isNotEmpty
                    ? images.last['url'] as String?
                    : null;
                final id = t['id'] as String?;
                final artists = ((t['artists'] as List?) ?? const [])
                    .cast<Map<String, dynamic>>()
                    .map((a) => a['name'])
                    .join(', ');
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
              }),
            ],
          );
        },
      ),
    );
  }
}
