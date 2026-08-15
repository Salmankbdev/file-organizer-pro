import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import 'home_shell.dart';

/// Shown on first launch: introduces the app and lets the user choose their
/// folder (defaulting to Downloads). Nothing is modified automatically.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _features = [
    (Icons.folder_open, 'Scan any folder'),
    (Icons.drive_file_move_outlined, 'Organize by type'),
    (Icons.content_copy, 'Find duplicates'),
    (Icons.data_usage, 'Spot large files'),
    (Icons.undo, 'Undo any change'),
    (Icons.shield_outlined, '100% offline & safe'),
  ];

  Future<void> _getStarted(BuildContext context) async {
    final controller = AppScope.of(context);

    final folder = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose a folder to start with'),
        content: const Text(
          'You can change this later in Settings. We recommend starting '
          'with your Downloads folder.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final path = await FilePicker.platform.getDirectoryPath();
              if (context.mounted) Navigator.pop(context, path);
            },
            child: const Text('Browse…'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, FileUtils.defaultDownloadsPath() ?? ''),
            child: const Text('Use Downloads'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (folder != null && folder.isNotEmpty) {
      controller.settings.defaultFolder = folder;
    }
    controller.settings.onboardingDone = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _learnMore(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What is File Organizer Pro?'),
        content: const Text(
          'File Organizer Pro helps you take back control of your folders. '
          'Scan a folder to see what is in it, preview how files would be '
          'sorted into category folders, apply the changes with one click, '
          'and undo them any time. It also finds duplicate and oversized '
          'files.\n\n'
          'Everything runs locally on your computer. No account, no cloud, '
          'no tracking — your files never leave your machine.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.folder_copy_rounded,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text('File Organizer Pro',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Organize your files. Find duplicates. Free up space.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (icon, label) in _features)
                        Chip(
                          avatar: Icon(icon,
                              size: 18, color: scheme.primary),
                          label: Text(label),
                          backgroundColor: scheme.surfaceContainerHigh,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 52),
                      textStyle: Theme.of(context).textTheme.titleMedium,
                    ),
                    onPressed: () => _getStarted(context),
                    icon: const Icon(Icons.rocket_launch_outlined),
                    label: const Text('Get Started'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _learnMore(context),
                    child: const Text('Learn More'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
