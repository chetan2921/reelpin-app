import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/screens/app_shell/app_shell.dart';

void main() {
  test('controller queues the tab index selected before attach', () {
    final controller = AppShellController.forTest(chatEnabled: true);
    final selected = <int>[];

    controller.showSaved();
    controller.attachForTest(selected.add);

    expect(selected, [3]);
  });

  test('every shell tab maps to a distinct index (chat enabled)', () {
    final selected = <int>[];
    final controller = AppShellController.forTest(chatEnabled: true)
      ..attachForTest(selected.add);

    controller.showHome();
    controller.showMap();
    controller.showAsk();
    controller.showSaved();
    controller.showDiscover();

    expect(selected, [0, 1, 2, 3, 4]);
  });

  test('every shell tab maps to a distinct index (chat disabled)', () {
    final selected = <int>[];
    final controller = AppShellController.forTest(chatEnabled: false)
      ..attachForTest(selected.add);

    controller.showHome();
    controller.showMap();
    controller.showAsk(); // no chat tab in this build; must not select anything
    controller.showSaved();
    controller.showDiscover();

    expect(selected, [0, 1, 2, 3]);
  });
}
