import 'package:flutter/material.dart';

import '../state/theme_controller.dart';

/// App-bar button to switch between System / Light / Dark.
class ThemeMenuButton extends StatelessWidget {
  const ThemeMenuButton({super.key, required this.controller});

  final ThemeController controller;

  static IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  static String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return PopupMenuButton<ThemeMode>(
          tooltip: 'Theme',
          icon: Icon(_iconFor(controller.mode)),
          initialValue: controller.mode,
          onSelected: controller.setMode,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          itemBuilder: (context) => [
            for (final mode in ThemeMode.values)
              PopupMenuItem<ThemeMode>(
                value: mode,
                child: Row(
                  children: [
                    Icon(_iconFor(mode), size: 20),
                    const SizedBox(width: 12),
                    Text(_labelFor(mode)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
