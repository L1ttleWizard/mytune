import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';

class BottomPlayerBar extends StatelessWidget {
  const BottomPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final s = player.state;
    if (!s.hasTrack && !player.webPlayerReady) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 8),
            if (s.artworkUrl != null)
              CachedNetworkImage(
                imageUrl: s.artworkUrl!,
                width: 48,
                height: 48,
              )
            else
              Container(width: 48, height: 48, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title ?? (player.webPlayerReady ? 'Ready' : 'Loading…'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (s.artist != null)
                    Text(s.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: player.previous,
            ),
            IconButton(
              icon: Icon(s.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: player.togglePlay,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: player.next,
            ),
          ],
        ),
      ),
    );
  }
}
