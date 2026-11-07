import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/state/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('theme defaults to the system setting', () async {
    final controller = ThemeController();
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });

  test('theme choice is saved and restored', () async {
    final controller = ThemeController();
    await controller.setMode(ThemeMode.dark);

    final restored = ThemeController();
    await restored.load();
    expect(restored.mode, ThemeMode.dark);
  });
}
