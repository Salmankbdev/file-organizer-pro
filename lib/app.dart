import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

class FileOrganizerApp extends StatelessWidget {
  const FileOrganizerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller.settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'File Organizer Pro',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(controller.settings.accentSeed),
            darkTheme: AppTheme.dark(controller.settings.accentSeed),
            themeMode: controller.settings.themeMode,
            home: controller.settings.onboardingDone
                ? const HomeShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
