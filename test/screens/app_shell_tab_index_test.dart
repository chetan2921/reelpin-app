import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/screens/app_shell/app_shell.dart';

void main() {
  test('controller queues the tab index selected before attach', () {
    final controller = AppShellController();
    final selected = <int>[];

    controller.showSaved();
    controller.attachForTest(selected.add);

    expect(selected, [2]);
  });

  test('every shell tab maps to a distinct index', () {
    final selected = <int>[];
    final controller = AppShellController()..attachForTest(selected.add);

    controller.showHome();
    controller.showMap();
    controller.showSaved();
    controller.showDiscover();

    expect(selected, [0, 1, 2, 3]);
  });
}
