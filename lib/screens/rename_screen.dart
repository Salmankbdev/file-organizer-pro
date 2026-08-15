import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/category.dart';
import '../models/scanned_file.dart';
import '../services/rename_service.dart';
import '../widgets/common.dart';

/// Batch rename: derive new names for the scanned files with a pattern,
/// preview every change, then apply. Renames never overwrite and can be
/// undone from History.
class RenameScreen extends StatefulWidget {
  const RenameScreen({super.key});

  @override
  State<RenameScreen> createState() => _RenameScreenState();
}

class _RenameScreenState extends State<RenameScreen> {
  final _nameFilter = TextEditingController();
  FileCategory? _categoryFilter;
  RenameOptions _options = const RenameOptions();
  String? _planError;

  @override
  void dispose() {
    _nameFilter.dispose();
    super.dispose();
  }

  List<ScannedFile> _filteredFiles(AppController controller) {
    final scan = controller.currentScan;
    if (scan == null) return const [];
    final query = _nameFilter.text.trim().toLowerCase();
    return [
      for (final file in scan.files)
        if ((_categoryFilter == null ||
                file.category == _categoryFilter) &&
            (query.isEmpty || file.name.toLowerCase().contains(query)))
          file,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Batch Rename',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Rename many files at once with a pattern. Every change is '
                'previewed first, never overwrites an existing file, and can '
                'be undone.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: controller.currentScan == null
                    ? const EmptyState(
                        icon: Icons.folder_open,
                        title: 'Run a scan first',
                        message:
                            'Batch rename works on the results of the latest '
                            'scan. Go to the Scan screen and scan a folder.',
                      )
                    : _buildBody(context, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppController controller) {
    final files = _filteredFiles(controller);
    final plan = controller.renamePlan;
    if (_planError != null) return _ErrorCard(message: _planError!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            children: [
              _buildPatternCard(context, controller, files),
              const SizedBox(height: 16),
              if (controller.renamePhase == RenamePhase.applying)
                _RenameProgress(
                  done: controller.renameProgress,
                  total: controller.renameTotal,
                  current: controller.renameCurrent,
                )
              else if (plan == null)
                _PreviewPrompt(fileCount: files.length)
              else
                _PreviewView(
                  plan: plan,
                  existingNames: {
                    for (final f in controller.currentScan!.files)
                      f.name.toLowerCase(),
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (controller.renameMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(controller.renameMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        Row(
          children: [
            FilledButton.icon(
              onPressed: plan != null &&
                      controller.renamePhase != RenamePhase.applying
                  ? () => _confirmApply(context, controller)
                  : null,
              icon: const Icon(Icons.check),
              label: const Text('Apply renames'),
            ),
            const SizedBox(width: 12),
            if (controller.renamePhase == RenamePhase.done) ...[
              OutlinedButton.icon(
                onPressed: () => _undo(context, controller),
                icon: const Icon(Icons.undo),
                label: const Text('Undo this operation'),
              ),
              const SizedBox(width: 12),
            ],
            if (plan != null && controller.renamePhase != RenamePhase.done) ...[
              OutlinedButton.icon(
                onPressed: () => _rebuild(controller, files),
                icon: const Icon(Icons.refresh),
                label: const Text('Rebuild preview'),
              ),
              const SizedBox(width: 12),
            ],
            if (controller.renamePhase == RenamePhase.done)
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  controller.renamePlan = null;
                  controller.renameResult = null;
                  controller.renamePhase = RenamePhase.idle;
                  controller.renameMessage = null;
                }),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('New rename'),
              ),
          ],
        ),
      ],
    );
  }

  // --- Pattern builder ---------------------------------------------------

  Widget _buildPatternCard(
      BuildContext context, AppController controller, List<ScannedFile> files) {
    final categories = <FileCategory>{
      for (final f in controller.currentScan!.files) f.category,
    }.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _nameFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter by name',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                DropdownButton<FileCategory?>(
                  value: _categoryFilter,
                  hint: const Text('All categories'),
                  items: [
                    const DropdownMenuItem<FileCategory?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    for (final c in categories)
                      DropdownMenuItem<FileCategory?>(
                        value: c,
                        child: Text('${c.icon} ${c.label}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryFilter = v),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${files.length} file(s) selected',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RenameMode>(
              initialValue: _options.mode,
              decoration: const InputDecoration(
                labelText: 'Rename pattern',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final mode in RenameMode.values)
                  DropdownMenuItem(value: mode, child: Text(mode.label)),
              ],
              onChanged: (v) => setState(
                  () => _options = _options.copyWith(mode: v ?? _options.mode)),
            ),
            const SizedBox(height: 12),
            ..._modeFields(context),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: !_options.isValid || files.isEmpty
                  ? null
                  : () => _rebuild(controller, files),
              icon: const Icon(Icons.preview_outlined),
              label: const Text('Preview names'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _modeFields(BuildContext context) {
    final style = const InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
    );
    switch (_options.mode) {
      case RenameMode.findReplace:
        return [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: style.copyWith(labelText: 'Find'),
                  onChanged: (v) => setState(
                      () => _options = _options.copyWith(find: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: style.copyWith(labelText: 'Replace with'),
                  onChanged: (v) => setState(
                      () => _options = _options.copyWith(replace: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _options.caseSensitive,
                onChanged: (v) => setState(
                    () => _options = _options.copyWith(caseSensitive: v)),
              ),
              const Text('Case sensitive'),
              const SizedBox(width: 24),
              Switch(
                value: _options.replaceAll,
                onChanged: (v) => setState(
                    () => _options = _options.copyWith(replaceAll: v)),
              ),
              const Text('Replace all occurrences'),
            ],
          ),
        ];
      case RenameMode.prefix:
        return [
          TextField(
            decoration: style.copyWith(labelText: 'Prefix'),
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(prefix: v)),
          ),
        ];
      case RenameMode.suffix:
        return [
          TextField(
            decoration: style.copyWith(labelText: 'Suffix (before extension)'),
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(suffix: v)),
          ),
        ];
      case RenameMode.numbering:
        return [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: style.copyWith(labelText: 'Prefix'),
                  onChanged: (v) =>
                      setState(() => _options = _options.copyWith(prefix: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: style.copyWith(labelText: 'Suffix'),
                  onChanged: (v) =>
                      setState(() => _options = _options.copyWith(suffix: v)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  decoration: style.copyWith(labelText: 'Start at'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _options = _options
                      .copyWith(startAt: int.tryParse(v) ?? 1)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  decoration: style.copyWith(labelText: 'Padding'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _options = _options
                      .copyWith(padding: int.tryParse(v) ?? 3)),
                ),
              ),
            ],
          ),
        ];
      case RenameMode.case_:
        return [
          DropdownButtonFormField<CaseMode>(
            initialValue: _options.caseMode,
            decoration: style.copyWith(labelText: 'Convert to'),
            items: [
              for (final mode in CaseMode.values)
                DropdownMenuItem(
                    value: mode,
                    child: Text('${mode.label}  ·  e.g. ${mode.example}')),
            ],
            onChanged: (v) => setState(
                () => _options = _options.copyWith(caseMode: v ?? _options.caseMode)),
          ),
        ];
    }
  }

  // --- Actions -----------------------------------------------------------

  void _rebuild(AppController c, List<ScannedFile> files) {
    final error = c.prepareRename(files, _options);
    setState(() => _planError = error);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmApply(BuildContext context, AppController c) async {
    final plan = c.renamePlan!;
    if (c.settings.confirmOrganize) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Apply renames?'),
          content: Text(
            'Rename ${plan.renames.length} file(s) inside '
            '${plan.rootPath}?\\n\\n'
            'Existing files are never overwritten, and the rename can be '
            'undone afterwards.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Rename')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await c.applyRename();
  }

  Future<void> _undo(BuildContext context, AppController c) async {
    final message = await c.undoLast();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message ?? 'Nothing to undo.')));
    }
  }
}

class _PreviewPrompt extends StatelessWidget {
  const _PreviewPrompt({required this.fileCount});

  final int fileCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.preview_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileCount == 0
                    ? 'No files match the current filters.'
                    : 'Choose a pattern above and preview how '
                        '$fileCount file(s) would be renamed. Nothing '
                        'changes until you apply.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({required this.plan, required this.existingNames});

  final RenamePlan plan;
  final Set<String> existingNames;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conflicts = plan.conflicts(existingNames);
    final changed = plan.renames.length;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '$changed file(s) will be renamed'
              '${conflicts.isNotEmpty ? ' · ${conflicts.length} conflict(s) will be resolved safely' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
          ),
          for (final rename in plan.renames)
            ListTile(
              dense: true,
              leading: Icon(
                conflicts.contains(rename)
                    ? Icons.warning_amber_outlined
                    : Icons.arrow_forward,
                size: 18,
                color: conflicts.contains(rename) ? scheme.error : null,
              ),
              title: Text(rename.file.name,
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              subtitle: Text(rename.newName,
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              trailing: conflicts.contains(rename)
                  ? Icon(Icons.info_outline, size: 16, color: scheme.error)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _RenameProgress extends StatelessWidget {
  const _RenameProgress({
    required this.done,
    required this.total,
    required this.current,
  });

  final int done;
  final int total;
  final String current;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? null : done / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Renaming… $done / $total',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(current,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }
}
