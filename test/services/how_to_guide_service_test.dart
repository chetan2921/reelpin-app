import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/services/how_to_guide_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = HowToGuideService.instance;

  Future<bool> empty() async => false;
  Future<bool> hasReels() async => true;

  test('a fresh install owes nothing until onboarding arms it', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await service.takePendingGuide(hasExistingSaves: empty), isFalse);

    await service.markGuidePending();
    expect(await service.takePendingGuide(hasExistingSaves: empty), isTrue);
  });

  test('the guide is owed exactly once', () async {
    SharedPreferences.setMockInitialValues({});
    await service.markGuidePending();

    expect(await service.takePendingGuide(hasExistingSaves: empty), isTrue);
    expect(await service.takePendingGuide(hasExistingSaves: empty), isFalse);
  });

  test(
    'an update carrying the old seen flag never re-arms the guide',
    () async {
      // What a 1.0.15 user has on disk after being walked through it once.
      SharedPreferences.setMockInitialValues({
        'how_to_guide_seen_v1_user-123': true,
      });

      expect(await service.takePendingGuide(hasExistingSaves: empty), isFalse);
    },
  );

  test('an account that already has reels is not walked through it', () async {
    // A reinstall: the install is fresh, so onboarding runs and arms the flag,
    // but the account behind it is not.
    SharedPreferences.setMockInitialValues({});
    await service.markGuidePending();

    expect(await service.takePendingGuide(hasExistingSaves: hasReels), isFalse);
  });

  test('a reinstall is not owed the guide on the next launch either', () async {
    SharedPreferences.setMockInitialValues({});
    await service.markGuidePending();
    await service.takePendingGuide(hasExistingSaves: hasReels);

    // The flag is spent whether or not the walkthrough was shown, so a user
    // who saves nothing after signing back in still does not get ambushed by
    // it on the next cold start.
    expect(await service.takePendingGuide(hasExistingSaves: empty), isFalse);
  });

  test('a library that cannot be counted stays quiet', () async {
    SharedPreferences.setMockInitialValues({});
    await service.markGuidePending();

    expect(
      await service.takePendingGuide(
        hasExistingSaves: () async => throw Exception('offline'),
      ),
      isFalse,
    );
  });
}
