import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/screens/how_to/how_to_use_screen.dart';

/// Screens the guide has to survive. The hotspot is positioned by fractions of
/// the screenshot, so the risk is not the maths drifting — it is the chrome
/// squeezing the stage until the circle is clipped or off-screen.
const _sizes = <String, Size>{
  'small phone': Size(320, 568),
  'common phone': Size(360, 800),
  'large phone': Size(430, 932),
  'tablet portrait': Size(800, 1280),
  'landscape': Size(800, 360),
};

Future<void> _pumpGuide(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.android,
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
      theme: ThemeData(platform: platform),
      home: const HowToUseScreen(isFirstRun: true),
    ),
  );
  await tester.pump();
}

/// The hotspot pulse repeats forever, so [WidgetTester.pumpAndSettle] never
/// settles. Advance past the step transition explicitly instead.
Future<void> _settleTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final entry in _sizes.entries) {
    testWidgets('lays out without overflow on ${entry.key}', (tester) async {
      await _pumpGuide(tester, size: entry.value);

      expect(tester.takeException(), isNull);
      expect(find.text('STEP 1/4'), findsOneWidget);
    });

    testWidgets('hotspot stays tappable on ${entry.key}', (tester) async {
      await _pumpGuide(tester, size: entry.value);

      // A hotspot pushed off-stage or clipped by the frame would fail the hit
      // test here rather than silently stranding the user on step one.
      await tester.tap(find.byKey(howToHotspotKey));
      await _settleTransition(tester);

      // Asserted by step number, not title, so this stays true whichever
      // platform's captures are in play.
      expect(find.text('STEP 2/4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in _sizes.entries) {
    testWidgets('header sits at the top on ${entry.key}', (tester) async {
      await _pumpGuide(tester, size: entry.value);

      // Centring the column used to split the leftover space above and below,
      // leaving a visible gap over the step chip. The stage absorbs it now.
      final chipTop = tester.getTopLeft(find.text('STEP 1/4')).dy;
      expect(chipTop, lessThan(48));
    });
  }

  testWidgets('fills the screen without scrolling on a phone', (tester) async {
    await _pumpGuide(tester, size: const Size(360, 800));

    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    expect(scrollable.controller?.position.maxScrollExtent ?? 0, 0);
  });

  testWidgets('scrolls instead of overflowing at 2x system text', (
    tester,
  ) async {
    await _pumpGuide(tester, size: const Size(320, 568), textScale: 2);

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage keeps a consistent shape rather than filling the screen', (
    tester,
  ) async {
    await _pumpGuide(tester, size: const Size(800, 1280));

    // On a tablet the capture is centred at a phone-ish width instead of being
    // blown up to the full 800pt, which is what made it look stretched.
    final stage = tester.getSize(find.byType(AspectRatio));
    expect(stage.width, lessThanOrEqualTo(430));
    expect(stage.height / stage.width, closeTo(1 / 0.62, 0.01));
  });

  for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
    final name = platform.name;

    testWidgets('walks through every step to the end on $name', (tester) async {
      await _pumpGuide(tester, size: const Size(360, 800), platform: platform);

      for (var step = 2; step <= 4; step++) {
        await tester.tap(find.byKey(howToHotspotKey));
        await _settleTransition(tester);
        expect(find.text('STEP $step/4'), findsOneWidget);
      }

      expect(find.text('PICK REELPIN'), findsOneWidget);
      expect(find.text('TAP REELPIN TO FINISH'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every step keeps its hotspot in frame on $name', (
      tester,
    ) async {
      await _pumpGuide(tester, size: const Size(360, 800), platform: platform);

      // Each capture is panned so its own highlight lands inside the visible
      // window — including the iOS rounded-rectangle one, which sits mid-image.
      for (var step = 1; step <= 4; step++) {
        final stage = tester.getRect(find.byType(AspectRatio));
        final hotspot = tester.getRect(find.byKey(howToHotspotKey));
        expect(stage.contains(hotspot.center), isTrue, reason: 'step $step');
        if (step == 4) break;
        await tester.tap(find.byKey(howToHotspotKey));
        await _settleTransition(tester);
      }
    });

    testWidgets('tapping away from the highlight nudges on $name', (
      tester,
    ) async {
      await _pumpGuide(tester, size: const Size(360, 800), platform: platform);

      // Top-left of the stage is artwork, never the highlight, on step one.
      final stage = tester.getRect(find.byType(AspectRatio));
      await tester.tapAt(stage.topLeft + const Offset(12, 12));
      await _settleTransition(tester);

      expect(find.text('STEP 1/4'), findsOneWidget);
      expect(find.text('TAP INSIDE THE HIGHLIGHTED CIRCLE'), findsOneWidget);
    });
  }
}
