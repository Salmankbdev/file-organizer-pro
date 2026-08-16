import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickDefaultFolder(AppController controller) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null && path.isNotEmpty) {
      controller.settings.defaultFolder = path;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),

              // --- General ---
              const SectionHeader('General'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('Default folder'),
                      subtitle: Text(
                        settings.defaultFolder ?? 'Not set',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (settings.defaultFolder != null)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  controller.settings.defaultFolder = null,
                            ),
                          OutlinedButton(
                            onPressed: () =>
                                _pickDefaultFolder(controller),
                            child: const Text('Browse'),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.rocket_launch_outlined),
                      title: const Text('Scan default folder on start'),
                      subtitle: const Text(
                          'Automatically scan the default folder when the '
                          'app opens.'),
                      value: settings.autoScanOnStart,
                      onChanged: (v) => controller.settings.autoScanOnStart = v,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.question_mark_outlined),
                      title: const Text('Confirm before organizing'),
                      value: settings.confirmOrganize,
                      onChanged: (v) => controller.settings.confirmOrganize = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Appearance ---
              const SectionHeader('Appearance'),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Theme mode',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System')),
                          ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light')),
                          ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark')),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) =>
                            controller.settings.themeMode = s.first,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Accent color',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            children: [
                              for (final color in AppTheme.accentOptions)
                                _ColorDot(
                                  color: color,
                                  selected:
                                      settings.accentSeed.toARGB32() ==
                                          color.toARGB32(),
                                  onTap: () =>
                                      controller.settings.accentSeed = color,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Storage ---
              const SectionHeader('Storage'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Database location'),
                      subtitle: const Text(
                          'Scan summaries, rules and operation history live '
                          'in a local SQLite file. No user files are copied '
                          'into it.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined),
                      title: const Text('Clear operation history'),
                      subtitle: const Text(
                          'Removes all recorded moves. This does not undo '
                          'them.'),
                      trailing: OutlinedButton(
                        onPressed: () =>
                            _confirmClearHistory(context, controller),
                        child: const Text('Clear'),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('Cache cleaner'),
                      subtitle: Text(
                        '${controller.cacheScanCount} stored scan '
                        'summary(ies), the demo sample folder and database '
                        'overhead — ${humanSize(controller.cacheBytes)} on '
                        'disk. Your files, rules and history are kept.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => _confirmClearCache(context, controller),
                        child: const Text('Clean'),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('Reset all settings'),
                      subtitle: const Text(
                          'Restores defaults, clears preferences, history '
                          'and rules, and returns to the welcome screen.'),
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error),
                        onPressed: () =>
                            _confirmReset(context, controller),
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Safety ---
              const SectionHeader('Safety'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.delete_outline),
                      title: const Text('Confirm before deleting'),
                      subtitle: const Text(
                          'Ask for confirmation before any file is removed.'),
                      value: settings.confirmDelete,
                      onChanged: (v) => controller.settings.confirmDelete = v,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.shield_outlined),
                      title: const Text('System-folder protection'),
                      subtitle: const Text(
                          'Refuse to reorganize Windows, Program Files and '
                          'other system folders.'),
                      value: settings.protectSystemFolders,
                      onChanged: (v) =>
                          controller.settings.protectSystemFolders = v,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.sync_problem_outlined),
                      title: const Text('Prevent overwriting'),
                      subtitle: const Text(
                          'When a file name already exists, add " (1)" '
                          'instead of replacing the file.'),
                      value: settings.preventOverwrite,
                      onChanged: (v) =>
                          controller.settings.preventOverwrite = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- About ---
              const SectionHeader('About'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('File Organizer Pro v1.7.0'),
                      subtitle: const Text(
                          'Scans, organizes and undoes everything locally. '
                          'No account, no internet required.'),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Windows shows "Windows protected your PC" '
                              'when you run the installer or the portable '
                              'exe? That is normal — the release binaries '
                              'are not code-signed, so Windows cannot '
                              'verify the publisher. Click More info → Run '
                              'anyway. The files are safe: fully open '
                              'source, offline, and scanned clean by '
                              'Windows Defender.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(
      BuildContext context, AppController controller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear operation history?'),
        content: const Text(
            'All recorded moves will be removed. This does NOT undo them — '
            'files stay where they are.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.clearHistory();
  }

  Future<void> _confirmClearCache(
      BuildContext context, AppController controller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cleaning_services_outlined),
        title: const Text('Clean all cache?'),
        content: Text(
            'This removes everything regenerable:\n'
            '\u2022 ${controller.cacheScanCount} stored scan '
            'summary(ies)\n'
            '\u2022 Demo sample folder\n'
            '\u2022 Database journal overhead\n\n'
            'Your files are never touched. Rules, operation history and '
            'settings are kept — re-scan to rebuild the cache.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clean'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final result = await controller.clearCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.freedNothing
                ? 'Cache cleaned — nothing to free.'
                : 'Cache cleaned — ${humanSize(result.bytesFreed)} freed.')));
      }
    }
  }

  Future<void> _confirmReset(
      BuildContext context, AppController controller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Reset everything?'),
        content: const Text(
            'Preferences, history and rules will be wiped and the app will '
            'restart to the welcome screen. Your files are never touched.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await controller.resetAll();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    }
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            width: selected ? 3 : 1,
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
