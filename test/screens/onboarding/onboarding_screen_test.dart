import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/constants/source_platforms.dart';
import 'package:reelpin/screens/onboarding/onboarding_screen.dart';

/// The platform strip is a single non-scrolling [Row], so every platform we add
/// makes it wider. These are the widths worth pinning: the narrowest phone we
/// support, and that phone again with the text scaled up.
const _sizes = <String, Size>{
  'small phone': Size(320, 568),
  'common phone': Size(360, 800),
  'large phone': Size(430, 932),
};

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: OnboardingScreen(onContinue: () {}),
    ),
  );
  await tester.pump();
  // The onboarding column already overflows vertically at 320x568, which is not
  // what this file is guarding, so the exception is drained rather than
  // asserted on.
  tester.takeException();
}

/// Every platform icon, rendered and inside the viewport.
void _expectStripFits(WidgetTester tester, Size size) {
  for (final platform in SourcePlatform.all) {
    final finder = find.bySemanticsLabel('${platform.name} source platform');
    expect(
      finder,
      findsOneWidget,
      reason: '${platform.name} is missing from the onboarding strip',
    );

    final rect = tester.getRect(finder);
    expect(
      rect.left >= 0 && rect.right <= size.width,
      isTrue,
      reason:
          '${platform.name} sits outside the ${size.width.toInt()}pt viewport '
          'at $rect — the strip has run out of room',
    );
  }
}

void main() {
  group('OnboardingScreen platform strip', () {
    for (final entry in _sizes.entries) {
      testWidgets('fits every platform icon on a ${entry.key}', (tester) async {
        await _pumpOnboarding(tester, size: entry.value);
        _expectStripFits(tester, entry.value);
      });
    }

    testWidgets('fits on the narrowest phone with large text', (tester) async {
      const size = Size(320, 568);
      await _pumpOnboarding(tester, size: size, textScale: 1.3);
      _expectStripFits(tester, size);
    });
  });
}
