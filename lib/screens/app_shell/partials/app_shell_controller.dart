part of '../app_shell.dart';

/// Tab positions, so the order lives in one place. The bar reads
/// HOME / MAP / SAVED / DISCOVER.
class _AppTab {
  const _AppTab._();

  static const home = 0;
  static const map = 1;
  static const saved = 2;
  static const discover = 3;
}

class AppShellController {
  ValueChanged<int>? _selectTab;
  int? _pendingTabIndex;

  void showHome() {
    _select(_AppTab.home);
  }

  void showMap() {
    _select(_AppTab.map);
  }

  void showSaved() {
    _select(_AppTab.saved);
  }

  void showDiscover() {
    _select(_AppTab.discover);
  }

  void _select(int index) {
    final callback = _selectTab;
    if (callback == null) {
      _pendingTabIndex = index;
      return;
    }
    callback(index);
  }

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
