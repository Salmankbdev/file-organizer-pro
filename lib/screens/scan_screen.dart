import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/category.dart';
import '../models/scanned_file.dart';
import '../models/scan_result.dart';
import '../widgets/common.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _pathController = TextEditingController();
  String _query = '';
  FileCategory? _categoryFilter;
  double? _minMb;
  double? _maxMb;
  DateTime? _from;
  DateTime? _to;
  bool _sortAscending = true;
  int? _sortColumn;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder(AppController controller) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null && path.isNotEmpty) {
      _pathController.text = path;
    }
  }

  Future<void> _startScan(AppController controller) async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a folder to scan first.')),
      );
      return;
    }
    await controller.scanFolder(path);
  }

  List<ScannedFile> _visible(ScanResult scan) {
    var files = scan.files;
    if (_categoryFilter != null) {
      files = files
          .where((f) => f.category == _categoryFilter)
          .toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      files = files.where((f) =>
          f.name.toLowerCase().contains(q) ||
          f.extension.toLowerCase().contains(q) ||
          f.path.toLowerCase().contains(q)).toList();
    }
    if (_minMb != null) {
      final minBytes = (_minMb! * 1024 * 1024).round();
      files = files.where((f) => f.size >= minBytes).toList();
    }
    if (_maxMb != null) {
      final maxBytes = (_maxMb! * 1024 * 1024).round();
      files = files.where((f) => f.size <= maxBytes).toList();
    }
    if (_from != null) {
      files = files.where((f) => !f.modified.isBefore(_from!)).toList();
    }
    if (_to != null) {
      final end = _to!.add(const Duration(days: 1));
      files = files.where((f) => f.modified.isBefore(end)).toList();
    }
    final column = _sortColumn;
    if (column != null) {
      files.sort((a, b) {
        int cmp;
        switch (column) {
          case 0:
            cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case 1:
            cmp = a.category.index.compareTo(b.category.index);
          case 2:
            cmp = a.size.compareTo(b.size);
          default:
            cmp = a.modified.compareTo(b.modified);
        }
        return _sortAscending ? cmp : -cmp;
      });
    }
    return files;
  }

  void _setSort(int columnIndex) {
    setState(() {
      if (_sortColumn == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = columnIndex;
        _sortAscending = true;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => isFrom ? _from = picked : _to = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final scan = controller.currentScan;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan a Folder',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),

              // --- Folder picker ---
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pathController,
                      decoration: const InputDecoration(
                        labelText: 'Folder path',
                        hintText: 'e.g. C:\\Users\\You\\Downloads',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickFolder(controller),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: controller.scanPhase == ScanPhase.scanning
                        ? null
                        : () => _startScan(controller),
                    icon: const Icon(Icons.search),
                    label: const Text('Scan'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Progress ---
              if (controller.scanPhase == ScanPhase.scanning) ...[
                LinearProgressIndicator(
                  value: null,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scanning… ${controller.scanProgressFiles} files '
                  '(${FileUtils.humanSize(controller.scanProgressBytes)})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],

              if (controller.scanPhase == ScanPhase.error)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Scan failed: ${controller.scanError}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ),

              // --- Results ---
              if (scan != null) ...[
                _SummaryBar(scan: scan),
                const SizedBox(height: 16),
                if (scan.files.isEmpty)
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No files found',
                      message:
                          'This folder is empty, or all entries are folders.',
                    ),
                  )
                else ...[
                  _Filters(
                    query: _query,
                    onQueryChanged: (v) => setState(() => _query = v),
                    categoryFilter: _categoryFilter,
                    onCategoryChanged: (c) =>
                        setState(() => _categoryFilter = c),
                    minMb: _minMb,
                    maxMb: _maxMb,
                    onMinChanged: (v) => setState(() => _minMb = v),
                    onMaxChanged: (v) => setState(() => _maxMb = v),
                    from: _from,
                    to: _to,
                    onPickFrom: () => _pickDate(isFrom: true),
                    onPickTo: () => _pickDate(isFrom: false),
                    onClearDates: () => setState(() {
                      _from = null;
                      _to = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildTable(controller, scan)),
                ],
              ] else if (controller.scanPhase != ScanPhase.scanning)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.folder_open,
                    title: 'Nothing scanned yet',
                    message:
                        'Pick a folder (e.g. Downloads) and press Scan to '
                        'inspect its contents.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(AppController controller, ScanResult scan) {
    final files = _visible(scan);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      sortColumnIndex: _sortColumn,
                      sortAscending: _sortAscending,
                      columns: [
                        DataColumn(
                          label: const Text('Name'),
                          onSort: (i, _) => _setSort(0),
                        ),
                        DataColumn(
                          label: const Text('Category'),
                          onSort: (i, _) => _setSort(1),
                        ),
                        DataColumn(
                          label: const Text('Size'),
                          numeric: true,
                          onSort: (i, _) => _setSort(2),
                        ),
                        DataColumn(
                          label: const Text('Modified'),
                          onSort: (i, _) => _setSort(3),
                        ),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final f in files)
                          DataRow(cells: [
                            DataCell(Text(f.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1)),
                            DataCell(Text(
                                '${f.category.icon} ${f.category.label}')),
                            DataCell(Text(FileUtils.humanSize(f.size))),
                            DataCell(Text(FileUtils.humanDate(f.modified))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Open file',
                                  icon: const Icon(Icons.open_in_new,
                                      size: 18),
                                  onPressed: () => Shell.open(f.path),
                                ),
                                IconButton(
                                  tooltip: 'Show in folder',
                                  icon: const Icon(Icons.folder_open,
                                      size: 18),
                                  onPressed: () =>
                                      Shell.showInFolder(f.path),
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Showing ${files.length} of ${scan.fileCount} files',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.scan});

  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _Item(
              icon: Icons.description_outlined,
              label: 'Files',
              value: '${scan.fileCount}',
            ),
            _Item(
              icon: Icons.storage_outlined,
              label: 'Total size',
              value: FileUtils.humanSize(scan.totalSize),
            ),
            _Item(
              icon: Icons.timer_outlined,
              label: 'Took',
              value: FileUtils.humanDuration(scan.duration),
            ),
            if (scan.errorCount > 0)
              _Item(
                icon: Icons.warning_amber_outlined,
                label: 'Skipped',
                value: '${scan.errorCount} unreadable',
                color: scheme.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? scheme.primary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant)),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.onQueryChanged,
    required this.categoryFilter,
    required this.onCategoryChanged,
    required this.minMb,
    required this.maxMb,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final FileCategory? categoryFilter;
  final ValueChanged<FileCategory?> onCategoryChanged;
  final double? minMb;
  final double? maxMb;
  final ValueChanged<double?> onMinChanged;
  final ValueChanged<double?> onMaxChanged;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDates = from != null || to != null;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search name, extension, path…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
        ),
        DropdownButton<FileCategory?>(
          value: categoryFilter,
          hint: const Text('All categories'),
          items: [
            const DropdownMenuItem<FileCategory?>(
                value: null, child: Text('All categories')),
            for (final c in FileCategory.values)
              DropdownMenuItem<FileCategory?>(
                  value: c, child: Text('${c.icon} ${c.label}')),
          ],
          onChanged: onCategoryChanged,
        ),
        _SizeField(
          label: 'Min MB',
          value: minMb,
          onChanged: onMinChanged,
        ),
        _SizeField(
          label: 'Max MB',
          value: maxMb,
          onChanged: onMaxChanged,
        ),
        OutlinedButton(
          onPressed: onPickFrom,
          child: Text(from == null ? 'From…' : 'From ${FileUtils.humanDate(from!)}'),
        ),
        OutlinedButton(
          onPressed: onPickTo,
          child: Text(to == null ? 'To…' : 'To ${FileUtils.humanDate(to!)}'),
        ),
        if (hasDates)
          TextButton.icon(
            onPressed: onClearDates,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Clear dates'),
          ),
        if (hasDates)
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

class _SizeField extends StatelessWidget {
  const _SizeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => onChanged(double.tryParse(v.trim())),
      ),
    );
  }
}
