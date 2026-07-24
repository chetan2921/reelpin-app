import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/app/update_required_screen.dart';
import 'package:reelpin/core/platform/app_update_service.dart';

void main() {
  testWidgets('blocks navigation and starts the required update', (
    WidgetTester tester,
  ) async {
    var updateCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateRequiredScreen(
          update: _iosUpdate,
          onUpdate: () async {
            updateCalls += 1;
            return true;
          },
        ),
      ),
    );

    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(find.text('1.0.10  ->  1.0.11'), findsOneWidget);
    expect(find.text('SKIP'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);

    await tester.tap(find.text('UPDATE NOW'));
    await tester.pump();
    expect(updateCalls, 1);
  });

  testWidgets('shows a retry message when the store cannot open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateRequiredScreen(
          update: _iosUpdate,
          onUpdate: () async => false,
        ),
      ),
    );

    await tester.tap(find.text('UPDATE NOW'));
    await tester.pump();

    expect(
      find.text(
        'THE UPDATE COULD NOT START. CHECK YOUR CONNECTION AND TRY AGAIN.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small screen with enlarged text', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: UpdateRequiredScreen(
          update: _iosUpdate,
          onUpdate: () async => true,
        ),
      ),
    );

    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _iosUpdate = RequiredAppUpdate(
  platform: AppUpdatePlatform.ios,
  storeUri: Uri.parse('https://apps.apple.com/us/app/reelpin/id6777110022'),
  installedVersion: '1.0.10',
  latestVersion: '1.0.11',
);
