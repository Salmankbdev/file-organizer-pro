import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/category.dart';
import '../services/organizer_service.dart';
import '../widgets/common.dart';

enum _Mode { organize, extract }

class OrganizeScreen extends StatefulWidget {
  const OrganizeScreen({super.key});

  @override
  State<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends State<OrganizeScreen> {
  _Mode _mode = _Mode.organize;
  String? _planError;
  String? _extractError;

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
              Text('Organize Files',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                _mode == _Mode.organize
                    ? 'Preview how files would be sorted into category '
                        'folders, then apply the changes. Every move can be '
                        'undone.'
                    : 'Unpack zip, tar and gz archives into an Extracted/ '
                        'folder — safely, with undo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(
                    value: _Mode.organize,
                    icon: Icon(Icons.drive_file_move_outlined),
                    label: Text('Organize files'),
                  ),
                  ButtonSegment(
                    value: _Mode.extract,
                    icon: Icon(Icons.unarchive_outlined),
                    label: Text('Extract archives'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _mode == _Mode.organize
                    ? _buildOrganize(context, controller)
                    : _buildExtract(context, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Organize mode -----------------------------------------------------

  Widget _buildOrganize(BuildContext context, AppController controller) {
    final plan = controller.currentPlan;
    final scan = controller.currentScan;

    if (scan == null) {
      return const EmptyState(
        icon: Icons.folder_open,
        title: 'Run a scan first',
        message:
            'Organize works on the results of the latest scan. Go to the '
            'Scan screen and scan a folder.',
      );
    }
    if (_planError != null) return _ErrorCard(message: _planError!);
    if (plan == null) {
      return Column(
        children: [
          const Spacer(),
          const EmptyState(
            icon: Icons.preview_outlined,
            title: 'Ready to preview',
            message:
                'Build a move plan from the latest scan. Nothing is changed '
                'until you apply it.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              final error = controller.preparePlan();
              setState(() => _planError = error);
              if (error != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error)));
              }
            },
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Preview changes'),
          ),
          const Spacer(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: controller.organizePhase == OrganizePhase.applying
              ? _ApplyProgress(
                  done: controller.organizeProgress,
                  total: controller.organizeTotal,
                  current: controller.organizeCurrentFile,
                )
              : _PlanView(plan: plan),
        ),
        const SizedBox(height: 12),
        if (controller.organizeMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(controller.organizeMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        Row(
          children: [
            FilledButton.icon(
              onPressed: controller.organizePhase == OrganizePhase.applying
                  ? null
                  : () => _confirmApply(context, controller),
              icon: const Icon(Icons.check),
              label: const Text('Apply changes'),
            ),
            const SizedBox(width: 12),
            if (controller.organizePhase == OrganizePhase.done)
              OutlinedButton.icon(
                onPressed: controller.organizePhase == OrganizePhase.applying
                    ? null
                    : () => _undo(context, controller),
                icon: const Icon(Icons.undo),
                label: const Text('Undo this operation'),
              ),
            if (controller.organizePhase != OrganizePhase.done) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: controller.organizePhase == OrganizePhase.applying
                    ? null
                    : () => setState(
                        () => _planError = controller.preparePlan()),
                icon: const Icon(Icons.refresh),
                label: const Text('Rebuild plan'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --- Extract mode ------------------------------------------------------

  Widget _buildExtract(BuildContext context, AppController controller) {
    final scan = controller.currentScan;
    final plan = controller.extractPlan;
    final result = controller.extractResult;

    if (scan == null) {
      return const EmptyState(
        icon: Icons.folder_open,
        title: 'Run a scan first',
        message:
            'Archive extraction works on the latest scan. Go to the Scan '
            'screen and scan a folder.',
      );
    }
    if (_extractError != null) return _ErrorCard(message: _extractError!);

    if (controller.extractPhase == FindPhase.running) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Extracting ${controller.extractProgress} / '
                      '${controller.extractTotal} archives'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: controller.extractTotal == 0
                        ? null
                        : controller.extractProgress /
                            controller.extractTotal,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(controller.extractCurrent,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (plan.isEmpty) {
      return Column(
        children: [
          const Spacer(),
          const EmptyState(
            icon: Icons.unarchive_outlined,
            title: 'No archives to extract',
            message:
                'Zip, tar, gz and tgz files in the scanned folder can be '
                'unpacked here. (7z and rar need external tools and are not '
                'supported yet.)',
          ),
          const Spacer(),
        ],
      );
    }

    final totalSize = plan.fold<int>(0, (s, e) => s + e.file.size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            children: [
              Text(
                '${plan.length} archive(s) · ${FileUtils.humanSize(totalSize)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (final entry in plan)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(entry.file.name,
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                        subtitle: Text(
                            '${FileUtils.humanSize(entry.file.size)} → '
                            '${entry.label}'),
                        trailing: result == null
                            ? null
                            : Icon(
                                result.failed > 0
                                    ? Icons.warning_amber_outlined
                                    : Icons.check_circle_outline,
                                color: result.failed > 0
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Extracted ${result.filesWritten} file(s) from '
              '${result.archives} archive(s)'
              '${result.failed > 0 ? ', ${result.failed} failed' : ''}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        Row(
          children: [
            FilledButton.icon(
              onPressed: controller.extractPhase == FindPhase.running
                  ? null
                  : () => _confirmExtract(context, controller),
              icon: const Icon(Icons.unarchive_outlined),
              label: const Text('Extract archives'),
            ),
            if (result != null) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _undo(context, controller),
                icon: const Icon(Icons.undo),
                label: const Text('Undo extraction'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --- Actions -----------------------------------------------------------

  Future<void> _confirmApply(BuildContext context, AppController c) async {
    if (c.settings.confirmOrganize) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Apply organization?'),
          content: Text(
            'Move ${c.currentPlan!.moves.length} file(s) into category '
            'folders inside ${c.currentPlan!.rootPath}?\n\n'
            'You can undo this afterwards from the History screen.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apply')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await c.applyPlan();
  }

  Future<void> _confirmExtract(BuildContext context, AppController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extract archives?'),
        content: Text(
          'Unpack ${c.extractPlan.length} archive(s) into an Extracted/ '
          'folder inside the scanned folder?\n\n'
          'Existing files are never overwritten, and the extraction can be '
          'undone afterwards.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Extract')),
        ],
      ),
    );
    if (ok != true) return;
    await c.applyExtract();
  }

  Future<void> _undo(BuildContext context, AppController c) async {
    final message = await c.undoLast();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message ?? 'Nothing to undo.')));
    }
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan});

  final OrganizePlan plan;

  @override
  Widget build(BuildContext context) {
    final byCategory = plan.byCategory;
    final categories = byCategory.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    return ListView(
      children: [
        for (final entry in categories)
          _CategorySection(
            category: entry.key,
            moves: entry.value,
          ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.moves});

  final FileCategory category;
  final List<PlannedMove> moves;

  @override
  Widget build(BuildContext context) {
    final totalSize = moves.fold<int>(0, (sum, m) => sum + m.file.size);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Text(category.icon, style: const TextStyle(fontSize: 22)),
        title: Text(category.label),
        subtitle: Text(
            '${moves.length} file(s) · ${FileUtils.humanSize(totalSize)}'),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          // Only the visible rows are built — a preview with thousands of
          // moves must not block the UI thread by building every tile.
          const SizedBox(height: 4),
          SizedBox(
            height: (moves.length > 30 ? 30 : moves.length).toDouble() * 52,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemExtent: 52,
              itemCount: moves.length,
              itemBuilder: (context, index) {
                final move = moves[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_right_alt, size: 18),
                  title: Text(move.file.name,
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  subtitle: Text(
                    '${FileUtils.humanSize(move.file.size)} → '
                    '${move.file.category.label}/',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyProgress extends StatelessWidget {
  const _ApplyProgress({
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
            Text('Applying… $done / $total',
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
