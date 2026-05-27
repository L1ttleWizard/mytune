import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/spotify_api.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SpotifyApi _api = SpotifyApi(context.read<AuthService>());
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic>? _results;
  bool _loading = false;

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    setState(() => _loading = true);
    try {
      final r = await _api.search(q, types: ['track'], limit: 30);
      if (!mounted) return;
      setState(() => _results = r);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ((_results?['tracks']?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Songs, artists, albums…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (_, i) {
                final t = tracks[i];
                final album = t['album'] as Map<String, dynamic>?;
                final images =
                    (album?['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
                  subtitle: Text(artists),
                  onTap: () =>
                      context.read<PlayerService>().playTrack(t['id'] as String),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
