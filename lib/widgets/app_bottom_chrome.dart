import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tab_switcher.dart';
import 'bottom_player_bar.dart';

/// Persistent chrome shown at the bottom of every screen that lives under
/// the main tab structure (Home, Search, Library, Playlist, LikedSongs).
///
/// Composed of the [BottomPlayerBar] on top and a [NavigationBar] below it.
/// Tapping a destination from a deep route pops back to the root and then
/// switches the active tab so the user always returns to a top-level page.
class AppBottomChrome extends StatelessWidget {
  const AppBottomChrome({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<TabSwitcher>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BottomPlayerBar(),
        NavigationBar(
          selectedIndex: tabs.index,
          onDestinationSelected: (i) {
            // If we're on a pushed sub-route, get back to the root tab host.
            Navigator.of(context).popUntil((route) => route.isFirst);
            context.read<TabSwitcher>().setIndex(i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            NavigationDestination(
                icon: Icon(Icons.library_music), label: 'Library'),
          ],
        ),
      ],
    );
  }
}
