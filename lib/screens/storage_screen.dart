import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/category.dart';
import '../models/scanned_file.dart';
import '../models/scan_result.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Storage analytics: per-category usage with clean bars, the largest files,
/// and the largest folders — all computed from the latest scan.
class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final scan = controller.currentScan;

    if (scan == null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Storage Analytics',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Expanded(
                  child: EmptyState(
                    icon: Icons.pie_chart_outline,
                    title: 'Run a scan first',
                    message:
                        'Storage analytics are built from the latest scan.',
                  ),
                ),
                Center(
                  child: FilledButton.icon(
                    onPressed: () => context
                        .findAncestorStateOfType<HomeShellState>()
                        ?.select(1),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Go to Scan'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    final byCategory = scan.byCategory;
    final categoryBytes = <FileCategory, int>{
      for (final c in FileCategory.values)
        c: byCategory[c]!.fold<int>(0, (s, f) => s + f.size),
    };
    final total = scan.totalSize;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Storage Analytics',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '${scan.fileCount} files · ${FileUtils.humanSize(total)} in '
                '${_folderName(scan.folderPath)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // --- Per-category bars ---
              const SectionHeader('Storage by category'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final c in FileCategory.values)
                        if (categoryBytes[c]! > 0)
                          _CategoryBar(
                            category: c,
                            bytes: categoryBytes[c]!,
                            fraction: total == 0
                                ? 0
                                : categoryBytes[c]! / total,
                            fileCount: byCategory[c]!.length,
                          ),
                      if (total == 0)
                        Text('No files to show.',
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Largest files ---
              const SectionHeader('Largest files'),
              _TopList(
                emptyMessage: 'No files in this scan.',
                children: _largestFiles(scan),
                sizeOf: (f) => f.size,
                labelOf: (f) => f.name,
                subtitleOf: (f) => f.path,
              ),
              const SizedBox(height: 24),

              // --- Largest folders ---
              const SectionHeader('Largest folders'),
              _TopList(
                emptyMessage: 'No files in this scan.',
                children: _largestFolders(scan),
                sizeOf: (f) => f.size,
                labelOf: (f) => _folderName(f.path),
                subtitleOf: (f) => f.path,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top 10 files by size.
  List<ScannedFile> _largestFiles(ScanResult scan) {
    final list = [...scan.files]..sort((a, b) => b.size.compareTo(a.size));
    return list.take(10).toList();
  }

  /// Top 10 folders by total size (a file is represented by its parent).
  List<ScannedFile> _largestFolders(ScanResult scan) {
    final byFolder = <String, ({int size, String name})>{};
    for (final f in scan.files) {
      final parent = f.path.substring(0, f.path.length - f.name.length);
      final entry = byFolder[parent];
      byFolder[parent] = (
        size: (entry?.size ?? 0) + f.size,
        name: _folderName(parent),
      );
    }
    final entries = byFolder.entries.toList()
      ..sort((a, b) => b.value.size.compareTo(a.value.size));
    return [
      for (final e in entries.take(10))
        ScannedFile(
          path: e.key,
          name: e.value.name,
          extension: '',
          size: e.value.size,
          modified: DateTime.now(),
        ),
    ];
  }

  String _folderName(String path) {
    final parts =
        path.replaceAll(RegExp(r'[\\/]+$'), '').split(RegExp(r'[\\/]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => path);
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.bytes,
    required this.fraction,
    required this.fileCount,
  });

  final FileCategory category;
  final int bytes;
  final double fraction;
  final int fileCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Row(
              children: [
                Text(category.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(category.label,
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 110,
            child: Text(FileUtils.humanSize(bytes),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 70,
            child: Text('$fileCount files',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _TopList extends StatelessWidget {
  const _TopList({
    required this.children,
    required this.emptyMessage,
    required this.sizeOf,
    required this.labelOf,
    required this.subtitleOf,
  });

  final List<ScannedFile> children;
  final String emptyMessage;
  final int Function(ScannedFile) sizeOf;
  final String Function(ScannedFile) labelOf;
  final String Function(ScannedFile) subtitleOf;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(emptyMessage),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            ListTile(
              dense: true,
              leading: Text('${i + 1}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.outline)),
              title: Text(labelOf(children[i]),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              subtitle: Text(subtitleOf(children[i]),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              trailing: Text(FileUtils.humanSize(sizeOf(children[i])),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}
