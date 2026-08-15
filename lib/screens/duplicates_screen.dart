import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/duplicate_group.dart';
import '../models/scanned_file.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Finds groups of identical files by content hash and lets the user remove
/// copies — always behind an explicit, irreversible-deletion confirmation.
class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  final Set<String> _selected = {};

  Future<void> _run(AppController controller) async {
    setState(_selected.clear);
    await controller.findDuplicates();
  }

  Future<void> _deleteSelected(AppController controller) async {
    final groups = controller.duplicateGroups ?? const <DuplicateGroup>[];
    final paths = [
      for (final g in groups)
        for (final f in g.files)
          if (_selected.contains(f.path)) f.path,
    ];
    if (paths.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('Permanently delete files?'),
        content: Text(
          '${paths.length} duplicate file(s) will be permanently deleted. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await controller.deleteFiles(paths);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted $deleted of ${paths.length} file(s).'),
      ));
    }
    await _run(controller); // Re-scan remaining files.
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final scan = controller.currentScan;
    final groups = controller.duplicateGroups;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duplicate Files',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Files are compared by size, then by SHA-256 content hash — '
                'only identical files are reported.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              if (scan == null)
                Expanded(
                  child: Column(
                    children: [
                      const Spacer(),
                      const EmptyState(
                        icon: Icons.content_copy_outlined,
                        title: 'Run a scan first',
                        message:
                            'Duplicate detection works on the latest scan. '
                            'Scan a folder, then come back here.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context
                            .findAncestorStateOfType<HomeShellState>()
                            ?.select(1),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Go to Scan'),
                      ),
                      const Spacer(),
                    ],
                  ),
                )
              else if (controller.duplicatePhase == FindPhase.running)
                Expanded(
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: 360,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Hashing candidate files…'),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: controller.duplicateTotal == 0
                                    ? null
                                    : controller.duplicateProgress /
                                        controller.duplicateTotal,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${controller.duplicateProgress} / '
                                '${controller.duplicateTotal}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (groups == null)
                Expanded(
                  child: Column(
                    children: [
                      const Spacer(),
                      const EmptyState(
                        icon: Icons.manage_search,
                        title: 'Ready to scan for duplicates',
                        message:
                            'Finds groups of files that are byte-for-byte '
                            'identical and shows how much space copies waste.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _run(controller),
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Find duplicates'),
                      ),
                      const Spacer(),
                    ],
                  ),
                )
              else if (groups.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No duplicates found',
                    message:
                        'Every file in the scanned folder has unique content.',
                  ),
                )
              else ...[
                _SummaryBar(
                  groups: groups,
                  selectedCount: _selected.length,
                  onDelete: _selected.isEmpty
                      ? null
                      : () => _deleteSelected(controller),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      for (final group in groups)
                        _GroupCard(
                          group: group,
                          selected: _selected,
                          onToggle: (path, value) =>
                              setState(() => value ? _selected.add(path) : _selected.remove(path)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.groups,
    required this.selectedCount,
    required this.onDelete,
  });

  final List<DuplicateGroup> groups;
  final int selectedCount;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final files = groups.fold<int>(0, (s, g) => s + g.files.length);
    final wasted = groups.fold<int>(0, (s, g) => s + g.wastedBytes);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Item(icon: Icons.group_outlined, label: 'Groups', value: '${groups.length}'),
            const SizedBox(width: 24),
            _Item(icon: Icons.copy_all_outlined, label: 'Duplicate files', value: '$files'),
            const SizedBox(width: 24),
            _Item(icon: Icons.savings_outlined, label: 'Wasted space', value: FileUtils.humanSize(wasted)),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(selectedCount == 0
                  ? 'Delete selected'
                  : 'Delete selected ($selectedCount)'),
              style: selectedCount > 0
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.onToggle,
  });

  final DuplicateGroup group;
  final Set<String> selected;
  final void Function(String path, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.copy_all_outlined, size: 18, color: scheme.tertiary),
                const SizedBox(width: 8),
                Text('${group.files.length} identical copies',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(FileUtils.humanSize(group.size),
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'SHA-256: ${group.hash.substring(0, 16)}…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            for (final file in group.files) _fileRow(context, file),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(BuildContext context, ScannedFile file) {
    return CheckboxListTile(
      dense: true,
      value: selected.contains(file.path),
      onChanged: (v) => onToggle(file.path, v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(file.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: Text(file.path,
          overflow: TextOverflow.ellipsis, maxLines: 1),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Open file',
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: () => Shell.open(file.path),
          ),
          IconButton(
            tooltip: 'Show in folder',
            icon: const Icon(Icons.folder_open, size: 18),
            onPressed: () => Shell.showInFolder(file.path),
          ),
        ],
      ),
    );
  }
}
