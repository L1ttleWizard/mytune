import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// On-disk cache for the user's "Liked Songs" list.
///
/// The list is large for some users (thousands of tracks), so we keep it on
/// disk after a full sync and revalidate cheaply on next open by checking
/// just the first page from the API.
class LikedTracksCache {
  static const _fileName = 'liked_tracks_cache_v1.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<CachedLikedTracks?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final items =
          ((map['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
      return CachedLikedTracks(
        items: items,
        total: (map['total'] as num?)?.toInt() ?? items.length,
        firstTrackId: map['firstTrackId'] as String?,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
            (map['savedAt'] as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(CachedLikedTracks data) async {
    final f = await _file();
    await f.writeAsString(jsonEncode({
      'items': data.items,
      'total': data.total,
      'firstTrackId': data.firstTrackId,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class CachedLikedTracks {
  CachedLikedTracks({
    required this.items,
    required this.total,
    required this.firstTrackId,
    required this.savedAt,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final String? firstTrackId;
  final DateTime savedAt;
}

String? firstTrackIdOf(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return null;
  final t = items.first['track'];
  if (t is Map<String, dynamic>) {
    final id = t['id'];
    if (id is String) return id;
  }
  return null;
}
