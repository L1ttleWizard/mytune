import 'package:flutter/foundation.dart';

/// Holds the currently-selected primary tab (Home / Search / Library).
///
/// Lives at app scope so any nested screen can switch tabs by calling
/// [setIndex], typically after popping back to the root.
class TabSwitcher extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void setIndex(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }
}
