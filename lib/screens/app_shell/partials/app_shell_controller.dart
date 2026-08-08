part of '../app_shell.dart';

class AppShellController {
  ValueChanged<int>? _selectTab;
  int? _pendingTabIndex;

  void showHome() {
    _select(0);
  }

  void showMap() {
    _select(1);
  }

  void showDiscover() {
    _select(2);
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
