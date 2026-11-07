import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the saved theme choice before the first frame so there is no flash.
  final themeController = ThemeController();
  await themeController.load();

  runApp(GalleryApp(themeController: themeController));
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Gallery',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.mode,
          home: HomeShell(themeController: themeController),
        );
      },
    );
  }
}
