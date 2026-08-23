import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/view_models/theme_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restored() carries the stored choice into the first frame', () async {
    SharedPreferences.setMockInitialValues({'theme_mode_is_dark': true});

    final viewModel = await ThemeViewModel.restored();

    // Read before anything is built, so there is no light frame to correct.
    expect(viewModel.themeMode, ThemeMode.dark);
  });

  test('restored() defaults to light when nothing was chosen', () async {
    SharedPreferences.setMockInitialValues({});

    final viewModel = await ThemeViewModel.restored();

    expect(viewModel.themeMode, ThemeMode.light);
  });
}
