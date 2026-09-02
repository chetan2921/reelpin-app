import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/services/how_to_guide_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = HowToGuideService.instance;

  test('a fresh install owes nothing until onboarding arms it', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await service.takePendingGuide(), isFalse);

    await service.markGuidePending();
    expect(await service.takePendingGuide(), isTrue);
  });

  test('the guide is owed exactly once', () async {
    SharedPreferences.setMockInitialValues({});
    await service.markGuidePending();

    expect(await service.takePendingGuide(), isTrue);
    expect(await service.takePendingGuide(), isFalse);
  });

  test('an update carrying the old seen flag never re-arms the guide', () async {
    // What a 1.0.15 user has on disk after being walked through it once.
    SharedPreferences.setMockInitialValues({
      'how_to_guide_seen_v1_user-123': true,
    });

    expect(await service.takePendingGuide(), isFalse);
  });
}
