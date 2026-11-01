import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/services/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notification setup waits for the Firebase startup task', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NotificationService.instance;
    final firebase = Completer<void>();
    service.waitForFirebaseInitialization(firebase.future);
    addTearDown(() => service.waitForFirebaseInitialization(Future.value()));

    var initialized = false;
    final pending = service.initialize(requestPermissions: false).then((_) {
      initialized = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(initialized, isFalse);
    firebase.complete();
    await pending;
    expect(initialized, isTrue);
  });
}
