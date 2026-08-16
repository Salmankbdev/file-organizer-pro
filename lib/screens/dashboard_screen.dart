import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/category.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final row = controller.latestScanRow;
    final counts = controller.latestCategoryCounts();
    final totalFiles = (row?['file_count'] as num?)?.toInt() ?? 0;
    final totalSize = (row?['total_size'] as num?)?.toInt() ?? 0;
    final lastScan = row?['scanned_at'] == null
        ? null
        : DateTime.tryParse(row!['scanned_at'] as String);
    final organized = controller.organizedFileCount;
    final duplicateCount = controller.duplicateFileCount;
    final largeCount = controller.largeFiles?.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                row == null
                    ? 'Run your first scan to see the overview of a folder.'
                    : 'Overview of ${p.basename(row['folder_path'] as String)} '
                        '(${FileUtils.humanSize(totalSize)})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // --- Quick actions ---
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _goTo(context, 1), // Scan screen
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Scan Folder'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _goTo(context, 2), // Organize screen
                    icon: const Icon(Icons.drive_file_move),
                    label: const Text('Organize'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _goTo(context, 3), // Rename screen
                    icon: const Icon(Icons.drive_file_rename_outline),
                    label: const Text('Batch Rename'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _goTo(context, 4), // Duplicates screen
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Find Duplicates'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _goTo(context, 5), // Large Files screen
                    icon: const Icon(Icons.data_usage),
                    label: const Text('Find Large Files'),
                  ),
                  if (row == null)
                    FilledButton.tonalIcon(
                      onPressed: () => controller.loadDemoData(),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Try demo data'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Stat cards ---
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth >= 1100 ? 4 : (constraints.maxWidth >= 700 ? 3 : 2);
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      StatCard(
                        icon: Icons.description_outlined,
                        label: 'Total Files',
                        value: totalFiles.toString(),
                        subtitle: 'last scan',
                      ),
                      StatCard(
                        icon: Icons.storage_outlined,
                        label: 'Storage Used',
                        value: FileUtils.humanSize(totalSize),
                        subtitle: 'last scan',
                      ),
                      StatCard(
                        icon: Icons.copy_all_outlined,
                        label: 'Duplicate Files',
                        value: duplicateCount?.toString() ?? '—',
                        subtitle: duplicateCount == null ? null : 'latest run',
                      ),
                      StatCard(
                        icon: Icons.data_usage,
                        label: 'Large Files',
                        value: largeCount?.toString() ?? '—',
                        subtitle: largeCount == null ? null : 'latest run',
                      ),
                      StatCard(
                        icon: Icons.drive_file_move_outlined,
                        label: 'Organized Files',
                        value: organized.toString(),
                        subtitle: 'all time',
                      ),
                      StatCard(
                        icon: Icons.history,
                        label: 'Last Scan',
                        value: lastScan == null
                            ? 'Never'
                            : FileUtils.humanDate(lastScan),
                        subtitle: lastScan == null ? null : '$totalFiles files',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // --- Category breakdown ---
              if (counts != null && counts.isNotEmpty) ...[
                const SectionHeader('Files by Category'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in FileCategory.values)
                      if ((counts[c.name] ?? 0) > 0)
                        CategoryChip(c, count: counts[c.name]),
                  ],
                ),
              ],
              const SizedBox(height: 28),

              // --- Storage / scan cache ---
              const SectionHeader('Storage'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('Stored scans'),
                      subtitle: const Text(
                          'Scan summaries kept for the dashboard stats.'),
                      trailing: Text(
                        '${controller.cacheScanCount}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('Cache on disk'),
                      subtitle: const Text(
                          'Database files plus the demo sample folder.'),
                      trailing: Text(
                        FileUtils.humanSize(controller.cacheBytes),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _StorageBar(
                        segments: [
                          (
                            label: 'Scan cache',
                            bytes: controller.storageCacheBytes,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          (
                            label: 'History',
                            bytes: controller.storageHistoryBytes,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          (
                            label: 'Rules',
                            bytes: controller.storageRulesBytes,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Cleared from Settings → Storage → Clear scan cache.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
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

  void _goTo(BuildContext context, int index) {
    context.findAncestorStateOfType<HomeShellState>()?.select(index);
  }
}

/// A compact horizontal stacked bar showing how the app's stored data is
/// split between scan cache, history and rules.
class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.segments});

  final List<({String label, int bytes, Color color})> segments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = segments.fold<int>(0, (sum, s) => sum + s.bytes);
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            width: double.infinity,
            child: total == 0
                ? ColoredBox(color: scheme.surfaceContainerHighest)
                : Row(
                    children: [
                      for (final s in segments)
                        if (s.bytes > 0)
                          Expanded(
                            flex: s.bytes,
                            child: ColoredBox(color: s.color),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        if (total == 0)
          Text(
            'Nothing stored yet — scans, history and rules will appear here.',
            style: bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final s in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(s.label, style: bodySmall),
                    const SizedBox(width: 4),
                    Text(
                      FileUtils.humanSize(s.bytes),
                      style: bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
