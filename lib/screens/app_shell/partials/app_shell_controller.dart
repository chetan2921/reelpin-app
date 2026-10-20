part of '../app_shell.dart';

/// Index of each tab in the shell's [IndexedStack].
@visibleForTesting
class AppTabLayout {
  const AppTabLayout();

  final int home = 0;
  final int map = 1;
  final int saved = 2;
  final int discover = 3;
}

class AppShellController {
  final AppTabLayout _layout = const AppTabLayout();
  ValueChanged<int>? _selectTab;
  int? _pendingTabIndex;

  void showHome() {
    _select(_layout.home);
  }

  void showMap() {
    _select(_layout.map);
  }

  void showSaved() {
    _select(_layout.saved);
  }

  void showDiscover() {
    _select(_layout.discover);
  }

  void _select(int index) {
    final callback = _selectTab;
    if (callback == null) {
      _pendingTabIndex = index;
      return;
    }
    callback(index);
  }

  @visibleForTesting
  void attachForTest(ValueChanged<int> callback) => _attach(callback);

  void _attach(ValueChanged<int> callback) {
    _selectTab = callback;
    final pendingTabIndex = _pendingTabIndex;
    if (pendingTabIndex != null) {
      _pendingTabIndex = null;
      callback(pendingTabIndex);
    }
  }

  void _detach() {
    _selectTab = null;
  }
}
