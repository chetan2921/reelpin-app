import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ReelPinApp(isSupabaseConfigured: false),
    );
    expect(find.text('SUPABASE SETUP REQUIRED'), findsOneWidget);
  });
}
