import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/liked_tracks_cache.dart';
import '../services/player_service.dart';
import '../services/spotify_api.dart';
import '../widgets/app_bottom_chrome.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  static const int _pageSize = 50;

  late final SpotifyApi _api = SpotifyApi(context.read<AuthService>());
  final LikedTracksCache _cache = LikedTracksCache();

  final List<Map<String, dynamic>> _items = [];
  bool _initialLoadDone = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _total = 0;
  bool _usedCache = false;
  String _status = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _cache.load();
    if (cached != null && cached.items.isNotEmpty) {
      // Show cache instantly.
      setState(() {
        _items.addAll(cached.items);
        _total = cached.total;
        _hasMore = false;
        _initialLoadDone = true;
        _usedCache = true;
        _status = 'Cached ${cached.items.length} tracks';
      });
      // Validate in the background.
      _revalidateAgainstApi(cached);
    } else {
      await _fetchAll();
    }
  }

  Future<void> _revalidateAgainstApi(CachedLikedTracks cached) async {
    try {
      setState(() => _status = 'Checking for updates…');
      final res = await _api.mySavedTracks(limit: _pageSize, offset: 0);
      final page = ((res['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final apiTotal = (res['total'] as num?)?.toInt() ?? page.length;
      final apiFirstId = firstTrackIdOf(page);
      if (apiTotal == cached.total && apiFirstId == cached.firstTrackId) {
        if (mounted) setState(() => _status = '');
        return;
      }
      // Something changed — re-sync entirely.
      if (mounted) {
        setState(() {
          _items.clear();
          _items.addAll(page);
          _total = apiTotal;
          _hasMore = _items.length < _total;
          _usedCache = false;
          _status =
              'List changed (was ${cached.total}, now $apiTotal) — refreshing…';
        });
      }
      await _loadRemainingInBackground();
    } catch (_) {
      if (mounted) setState(() => _status = '');
    }
  }

  Future<void> _fetchAll() async {
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
      await _loadRemainingInBackground();
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
      // Done — persist to cache.
      await _cache.save(CachedLikedTracks(
        items: _items,
        total: _total,
        firstTrackId: firstTrackIdOf(_items),
        savedAt: DateTime.now(),
      ));
      if (mounted) {
        setState(() => _status = 'Cached ${_items.length} tracks');
      }
    } catch (_) {
      // partial — don't overwrite a good cache
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Songs'),
        actions: [
          IconButton(
            tooltip: 'Refresh from Spotify',
            icon: const Icon(Icons.refresh),
            onPressed: _initialLoadDone
                ? () async {
                    await _cache.clear();
                    setState(() {
                      _items.clear();
                      _initialLoadDone = false;
                      _hasMore = true;
                      _usedCache = false;
                      _status = '';
                      _error = null;
                    });
                    await _fetchAll();
                  }
                : null,
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomChrome(),
      body: !_initialLoadDone
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildList(),
    );
  }

  Widget _buildList() {
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
                    : '$_total tracks${_usedCache ? " (from cache)" : ""}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_status.isNotEmpty)
                Text(_status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey, fontStyle: FontStyle.italic)),
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
