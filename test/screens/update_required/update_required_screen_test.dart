import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/app_config/remote_config.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/screens/update_required/update_required_screen.dart';

const _hard = UpdateRequirement(
  enabled: true,
  minBuildAndroid: 24,
  hard: true,
  title: 'TIME TO UPDATE',
  body: 'This build is retired.',
);

const _soft = UpdateRequirement(enabled: true, minBuildAndroid: 24);

void main() {
  testWidgets('a hard requirement offers only the store button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: UpdateRequiredScreen(requirement: _hard)),
    );

    expect(find.text('TIME TO UPDATE'), findsOneWidget);
    expect(find.text('This build is retired.'), findsOneWidget);
    expect(find.text('UPDATE NOW'), findsOneWidget);
    expect(find.text('NOT NOW'), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('back does not leave a hard requirement', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const UpdateRequiredScreen(requirement: _hard),
      ),
    );
    await tester.pumpAndSettle();

    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
  });

  testWidgets('a soft requirement can be dismissed', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
    navigatorKey.currentState!.push(updateRequiredRoute(_soft));
    await tester.pumpAndSettle();

    expect(find.text('UPDATE REELPIN'), findsOneWidget);
    expect(
      find.text('A NEWER VERSION OF REELPIN IS READY IN THE STORE.'),
      findsOneWidget,
    );
    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();

    expect(find.byType(UpdateRequiredScreen), findsNothing);
  });
}
