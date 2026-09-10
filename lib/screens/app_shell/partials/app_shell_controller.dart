part of '../app_shell.dart';

/// Index layout for the shell's tabs, computed from whether the chat tab
/// exists in this build. Kept as a pure function of a bool — rather than
/// reading the `chatEnabled` compile-time const directly — so both tab
/// configurations can be pinned by a test without a second build.
@visibleForTesting
class AppTabLayout {
  const AppTabLayout._({
    required this.home,
    required this.map,
    required this.ask,
    required this.saved,
    required this.discover,
  });

  factory AppTabLayout.forChatEnabled(bool chatEnabled) {
    return chatEnabled
        ? const AppTabLayout._(home: 0, map: 1, ask: 2, saved: 3, discover: 4)
        : const AppTabLayout._(
            home: 0,
            map: 1,
            ask: null,
            saved: 2,
            discover: 3,
          );
  }

  final int home;
  final int map;
  final int? ask; // null when the chat tab does not exist in this build.
  final int saved;
  final int discover;
}

class AppShellController {
  AppShellController() : _layout = AppTabLayout.forChatEnabled(chatEnabled);

  @visibleForTesting
  AppShellController.forTest({required bool chatEnabled})
    : _layout = AppTabLayout.forChatEnabled(chatEnabled);

  final AppTabLayout _layout;
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

  void showAsk() {
    // A stale deep link or queued notification can still target ASK after a
    // build without the chat tab; treat that as a no-op rather than an
    // out-of-range index.
    final index = _layout.ask;
    if (index == null) return;
    _select(index);
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
