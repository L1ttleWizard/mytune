import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  // Local seek position used while the user is dragging the slider.
  // When null, we display the live position from PlayerService.
  double? _draggingMs;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '${h.toString()}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final s = player.state;
    final durMs = s.duration.inMilliseconds.toDouble();
    final posMs =
        _draggingMs ?? s.position.inMilliseconds.toDouble().clamp(0, durMs);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Now Playing'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: s.artworkUrl != null
                      ? CachedNetworkImage(
                          imageUrl: s.artworkUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                s.title ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                s.artist ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Slider(
                min: 0,
                max: durMs <= 0 ? 1 : durMs,
                value: durMs <= 0 ? 0 : posMs.clamp(0, durMs).toDouble(),
                onChanged: durMs <= 0
                    ? null
                    : (v) => setState(() => _draggingMs = v),
                onChangeEnd: durMs <= 0
                    ? null
                    : (v) {
                        player.seek(Duration(milliseconds: v.toInt()));
                        setState(() => _draggingMs = null);
                      },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(Duration(milliseconds: posMs.toInt()))),
                  Text(_fmt(s.duration)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: player.previous,
                  ),
                  IconButton(
                    iconSize: 72,
                    icon: Icon(
                      s.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                    onPressed: player.togglePlay,
                  ),
                  IconButton(
                    iconSize: 40,
                    icon: const Icon(Icons.skip_next),
                    onPressed: player.next,
                  ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
