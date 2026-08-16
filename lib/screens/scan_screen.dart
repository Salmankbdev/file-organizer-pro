import 'dart:async';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/category.dart';
import '../models/scanned_file.dart';
import '../models/scan_result.dart';
import '../services/scan_filter.dart';
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

  // --- Filtering state (debounced + background isolate) ---
  Timer? _debounce;
  List<ScannedFile>? _filtered;
  bool _filtering = false;
  int _filterVersion = 0;
  ScanResult? _lastScan;

  static const _debounceDelay = Duration(milliseconds: 250);

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _categoryFilter != null ||
      _minMb != null ||
      _maxMb != null ||
      _from != null ||
      _to != null ||
      _sortColumn != null;

  @override
  void dispose() {
    _debounce?.cancel();
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

  /// Debounces query changes so typing doesn't filter on every keystroke.
  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _applyFilters);
  }

  /// Recomputes the filtered + sorted list on a background isolate so the
  /// UI thread never blocks, even for very large scans.
  Future<void> _applyFilters() async {
    final scan = _lastScan;
    if (scan == null) return;
    _debounce?.cancel();

    // Fast path: nothing to filter or sort — show the raw list.
    if (!_hasActiveFilters) {
      if (_filtered != null || _filtering) {
        setState(() {
          _filtered = null;
          _filtering = false;
        });
      }
      return;
    }

    final version = ++_filterVersion;
    setState(() => _filtering = true);

    final query = _query;
    final category = _categoryFilter;
    final minMb = _minMb;
    final maxMb = _maxMb;
    final from = _from;
    final to = _to;
    final sortColumn = _sortColumn;
    final sortAscending = _sortAscending;

    try {
      final result = await Isolate.run(
        () => filterAndSortFiles(
          scan.files,
          query: query,
          category: category,
          minMb: minMb,
          maxMb: maxMb,
          from: from,
          to: to,
          sortColumn: sortColumn,
          sortAscending: sortAscending,
        ),
      );
      // Discard results from superseded filter changes.
      if (!mounted || version != _filterVersion) return;
      setState(() {
        _filtered = result;
        _filtering = false;
      });
    } catch (_) {
      if (!mounted || version != _filterVersion) return;
      setState(() => _filtering = false);
    }
  }

  void _onFilterChanged(VoidCallback update) {
    setState(update);
    _applyFilters();
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
    _applyFilters();
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
      _onFilterChanged(() => isFrom ? _from = picked : _to = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final scan = controller.currentScan;

    // A new scan arrived: drop the cached filter results (they belong to the
    // previous scan) and recompute if any filter is active.
    if (scan != _lastScan) {
      _lastScan = scan;
      _filterVersion++;
      _filtered = null;
      _filtering = false;
      if (scan != null && _hasActiveFilters) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilters());
      }
    }

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
                        hintText: 'e.g. C:\\\\Users\\\\You\\\\Downloads',
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
                    onQueryChanged: _onQueryChanged,
                    categoryFilter: _categoryFilter,
                    onCategoryChanged: (c) =>
                        _onFilterChanged(() => _categoryFilter = c),
                    minMb: _minMb,
                    maxMb: _maxMb,
                    onMinChanged: (v) => _onFilterChanged(() => _minMb = v),
                    onMaxChanged: (v) => _onFilterChanged(() => _maxMb = v),
                    from: _from,
                    to: _to,
                    onPickFrom: () => _pickDate(isFrom: true),
                    onPickTo: () => _pickDate(isFrom: false),
                    onClearDates: () => _onFilterChanged(() {
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

  /// A virtualized, sortable table. Only the rows visible in the viewport are
  /// built, so results with tens of thousands of files render instantly and
  /// stay responsive while scrolling.
  Widget _buildTable(AppController controller, ScanResult scan) {
    final files = _filtered ?? scan.files;
    final scheme = Theme.of(context).colorScheme;

    const actionsWidth = 96.0;
    const categoryWidth = 150.0;
    const sizeWidth = 110.0;
    const modifiedWidth = 160.0;
    const fixedWidth = actionsWidth + categoryWidth + sizeWidth + modifiedWidth;
    const minNameWidth = 220.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            if (_filtering) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available = constraints.maxWidth;
                  final nameWidth =
                      (available - fixedWidth).clamp(minNameWidth, double.infinity);
                  final totalWidth = available > fixedWidth + minNameWidth
                      ? available
                      : fixedWidth + minNameWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _headerRow(
                            nameWidth: nameWidth,
                            categoryWidth: categoryWidth,
                            sizeWidth: sizeWidth,
                            modifiedWidth: modifiedWidth,
                            actionsWidth: actionsWidth,
                            scheme: scheme,
                          ),
                          Divider(height: 1, color: scheme.outlineVariant),
                          Expanded(
                            child: files.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('No files match the filters.'),
                                    ),
                                  )
                                : ListView.builder(
                                    itemExtent: 44,
                                    itemCount: files.length,
                                    itemBuilder: (context, index) =>
                                        _dataRow(
                                      files[index],
                                      nameWidth: nameWidth,
                                      categoryWidth: categoryWidth,
                                      sizeWidth: sizeWidth,
                                      modifiedWidth: modifiedWidth,
                                      actionsWidth: actionsWidth,
                                      context: context,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Showing ${files.length} of ${scan.fileCount} files'
                '${_filtering ? ' — filtering…' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow({
    required double nameWidth,
    required double categoryWidth,
    required double sizeWidth,
    required double modifiedWidth,
    required double actionsWidth,
    required ColorScheme scheme,
  }) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          _sortHeader(
            label: 'Name',
            column: 0,
            width: nameWidth,
            scheme: scheme,
            numeric: false,
          ),
          _sortHeader(
            label: 'Category',
            column: 1,
            width: categoryWidth,
            scheme: scheme,
            numeric: false,
          ),
          _sortHeader(
            label: 'Size',
            column: 2,
            width: sizeWidth,
            scheme: scheme,
            numeric: true,
          ),
          _sortHeader(
            label: 'Modified',
            column: 3,
            width: modifiedWidth,
            scheme: scheme,
            numeric: false,
          ),
          SizedBox(
            width: actionsWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortHeader({
    required String label,
    required int column,
    required double width,
    required ColorScheme scheme,
    required bool numeric,
  }) {
    final selected = _sortColumn == column;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _setSort(column),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(
            alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 2),
                  Icon(
                    _sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                    color: scheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataRow(
    ScannedFile f, {
    required double nameWidth,
    required double categoryWidth,
    required double sizeWidth,
    required double modifiedWidth,
    required double actionsWidth,
    required BuildContext context,
  }) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _cell(
            width: nameWidth,
            child: Text(f.name,
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
          _cell(
            width: categoryWidth,
            child: Text('${f.category.icon} ${f.category.label}',
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
          _cell(
            width: sizeWidth,
            alignRight: true,
            child: Text(FileUtils.humanSize(f.size)),
          ),
          _cell(
            width: modifiedWidth,
            child: Text(FileUtils.humanDate(f.modified)),
          ),
          SizedBox(
            width: actionsWidth,
            child: Row(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell({
    required double width,
    required Widget child,
    bool alignRight = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
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
