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
  static const int _pageSize = 50;

  late final SpotifyApi _api = SpotifyApi(context.read<AuthService>());
  final List<Map<String, dynamic>> _items = [];
  bool _initialLoadDone = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _total = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final res = await _api.mySavedTracks(limit: _pageSize, offset: 0);
      if (!mounted) return;
      final page = ((res['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _items.addAll(page);
        _total = (res['total'] as num?)?.toInt() ?? page.length;
        _hasMore = _items.length < _total;
        _initialLoadDone = true;
      });
      // Kick off background pagination without blocking the screen.
      _loadRemainingInBackground();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoadDone = true;
      });
    }
  }

  Future<void> _loadRemainingInBackground() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    if (mounted) setState(() {});
    try {
      while (_hasMore && mounted) {
        final res = await _api.mySavedTracks(
            limit: _pageSize, offset: _items.length);
        if (!mounted) return;
        final page = ((res['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
        if (page.isEmpty) {
          setState(() => _hasMore = false);
          break;
        }
        setState(() {
          _items.addAll(page);
          _hasMore = _items.length < _total;
        });
      }
    } catch (_) {
      // swallow — partial list is better than crashing
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liked Songs')),
      bottomNavigationBar: const BottomPlayerBar(),
      body: !_initialLoadDone
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildList(),
    );
  }

  Widget _buildList() {
    // +1 for header, +1 for footer (loading indicator or "all loaded" line).
    const headerCount = 1;
    const footerCount = 1;
    final total = headerCount + _items.length + footerCount;
    return ListView.builder(
      itemCount: total,
      itemBuilder: (context, i) {
        if (i == 0) return _buildHeader();
        if (i == total - 1) return _buildFooter();
        final item = _items[i - 1];
        return _trackTile(item);
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                _hasMore
                    ? '${_items.length} of $_total tracks'
                    : '$_total tracks',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
                onPressed: _items.isEmpty
                    ? null
                    : () {
                        final firstId = (_items.first['track']
                            as Map<String, dynamic>?)?['id'] as String?;
                        if (firstId != null) {
                          context.read<PlayerService>().playTrack(firstId);
                        }
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '${_items.length} tracks loaded',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _trackTile(Map<String, dynamic> item) {
    final t = item['track'] as Map<String, dynamic>? ?? {};
    final album = t['album'] as Map<String, dynamic>?;
    final images =
        (album?['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final url = images.isNotEmpty ? images.last['url'] as String? : null;
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
  }
}
