import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/scanned_file.dart';
import '../widgets/common.dart';

/// Finds files above a size threshold and lists them largest-first.
class LargeFilesScreen extends StatefulWidget {
  const LargeFilesScreen({super.key});

  @override
  State<LargeFilesScreen> createState() => _LargeFilesScreenState();
}

class _LargeFilesScreenState extends State<LargeFilesScreen> {
  static const _presets = <(String, int)>[
    ('100 MB', 100 * 1024 * 1024),
    ('500 MB', 500 * 1024 * 1024),
    ('1 GB', 1024 * 1024 * 1024),
  ];

  int? _presetBytes;
  final _customSize = TextEditingController();
  int? _customUnitMb; // 1 = MB, 1024 = GB

  @override
  void dispose() {
    _customSize.dispose();
    super.dispose();
  }

  Future<void> _run(AppController controller) async {
    var minBytes = _presetBytes;
    if (minBytes == null) {
      final raw = double.tryParse(_customSize.text.trim());
      if (raw == null || raw <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter a valid custom size, or pick a preset.')));
        return;
      }
      minBytes = (raw * (_customUnitMb ?? 1024) * 1024 * 1024).round();
    }
    await controller.findLargeFiles(minBytes);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final scan = controller.currentScan;
    final files = controller.largeFiles;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Large Files',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Find files that are larger than a size you choose.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // --- Size selector ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (label, bytes) in _presets)
                        ChoiceChip(
                          label: Text(label),
                          selected: _presetBytes == bytes,
                          onSelected: (v) => setState(() {
                            _presetBytes = v ? bytes : null;
                          }),
                        ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _customSize,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Custom size',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() => _presetBytes = null),
                        ),
                      ),
                      DropdownButton<int?>(
                        value: _customUnitMb,
                        hint: const Text('Unit'),
                        items: const [
                          DropdownMenuItem<int?>(value: 1, child: Text('MB')),
                          DropdownMenuItem<int?>(value: 1024, child: Text('GB')),
                        ],
                        onChanged: (v) => setState(() => _customUnitMb = v),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: scan == null ? null : () => _run(controller),
                        icon: const Icon(Icons.data_usage),
                        label: const Text('Find'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (scan == null)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.folder_open,
                    title: 'Run a scan first',
                    message:
                        'Large-file search works on the latest scan. Scan a '
                        'folder, then pick a size.',
                  ),
                )
              else if (controller.largePhase == FindPhase.running)
                const Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 260,
                      child: LinearProgressIndicator(minHeight: 6),
                    ),
                  ),
                )
              else if (files == null)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.data_usage,
                    title: 'Pick a size and press Find',
                    message:
                        'Results are sorted by size, largest first, with '
                        'actions to open, locate or delete each file.',
                  ),
                )
              else if (files.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Nothing that large',
                    message:
                        'No file is at least '
                        '${FileUtils.humanSize(controller.largeThresholdBytes)}.',
                  ),
                )
              else ...[
                Text(
                  '${files.length} file(s) ≥ '
                  '${FileUtils.humanSize(controller.largeThresholdBytes)} · '
                  '${FileUtils.humanSize(files.fold<int>(0, (s, f) => s + f.size))} total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildTable(context, controller, files)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
      BuildContext context, AppController controller, List<ScannedFile> files) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Size'), numeric: true),
                  DataColumn(label: Text('Modified')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final f in files)
                    DataRow(cells: [
                      DataCell(Text(f.name,
                          overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DataCell(Text(FileUtils.humanSize(f.size))),
                      DataCell(Text(FileUtils.humanDate(f.modified))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Open file',
                            icon: const Icon(Icons.open_in_new, size: 18),
                            onPressed: () => Shell.open(f.path),
                          ),
                          IconButton(
                            tooltip: 'Show in folder',
                            icon: const Icon(Icons.folder_open, size: 18),
                            onPressed: () => Shell.showInFolder(f.path),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: scheme.error),
                            onPressed: () => _confirmDelete(context, controller, f),
                          ),
                        ],
                      )),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppController controller, ScannedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('Permanently delete file?'),
        content: Text(
          '${file.name} (${FileUtils.humanSize(file.size)}) will be '
          'permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
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

    final deleted = await controller.deleteFiles([file.path]);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(deleted == 1
          ? 'Deleted ${file.name}.'
          : 'Could not delete ${file.name}.'),
    ));
    // Refresh the current results.
    await controller.findLargeFiles(controller.largeThresholdBytes);
  }
}
