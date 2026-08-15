import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/category.dart';
import '../services/organizer_service.dart';
import '../widgets/common.dart';

class OrganizeScreen extends StatefulWidget {
  const OrganizeScreen({super.key});

  @override
  State<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends State<OrganizeScreen> {
  String? _planError;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final plan = controller.currentPlan;
    final scan = controller.currentScan;

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
                plan == null
                    ? 'Preview how files would be sorted into category folders, '
                        'then apply the changes. Every move can be undone.'
                    : 'Prepared ${plan.moves.length} move(s) for '
                        '${_folderName(plan.rootPath)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              if (scan == null)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.folder_open,
                    title: 'Run a scan first',
                    message:
                        'Organize works on the results of the latest scan. '
                        'Go to the Scan screen and scan a folder.',
                  ),
                )
              else if (_planError != null)
                _ErrorCard(message: _planError!)
              else if (plan == null)
                Expanded(
                  child: Column(
                    children: [
                      const Spacer(),
                      const EmptyState(
                        icon: Icons.preview_outlined,
                        title: 'Ready to preview',
                        message:
                            'Build a move plan from the latest scan. '
                            'Nothing is changed until you apply it.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          final error = controller.preparePlan();
                          setState(() => _planError = error);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error)));
                          }
                        },
                        icon: const Icon(Icons.preview_outlined),
                        label: const Text('Preview changes'),
                      ),
                      const Spacer(),
                    ],
                  ),
                )
              else ...[
                if (controller.organizePhase == OrganizePhase.applying)
                  _ApplyProgress(
                    done: controller.organizeProgress,
                    total: controller.organizeTotal,
                    current: controller.organizeCurrentFile,
                  )
                else
                  Expanded(child: _PlanView(plan: plan)),
                const SizedBox(height: 12),
                if (controller.organizeMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(controller.organizeMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
                _ActionBar(
                  applying:
                      controller.organizePhase == OrganizePhase.applying,
                  applied: controller.organizePhase == OrganizePhase.done,
                  onApply: () => _confirmApply(context, controller),
                  onUndo: () => _undo(context, controller),
                  onReprepare: () =>
                      setState(() => _planError = controller.preparePlan()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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

  Future<void> _undo(BuildContext context, AppController c) async {
    final message = await c.undoLast();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message ?? 'Nothing to undo.')));
    }
  }

  String _folderName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => path);
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
    final totalSize =
        moves.fold<int>(0, (sum, m) => sum + m.file.size);
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
          for (final move in moves)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_right_alt, size: 18),
              title: Text(move.file.name,
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              subtitle: Text(
                '${FileUtils.humanSize(move.file.size)} → '
                '${category.label}/',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.applying,
    required this.applied,
    required this.onApply,
    required this.onUndo,
    required this.onReprepare,
  });

  final bool applying;
  final bool applied;
  final VoidCallback onApply;
  final VoidCallback onUndo;
  final VoidCallback onReprepare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: applying ? null : onApply,
          icon: const Icon(Icons.check),
          label: const Text('Apply changes'),
        ),
        const SizedBox(width: 12),
        if (applied)
          OutlinedButton.icon(
            onPressed: applying ? null : onUndo,
            icon: const Icon(Icons.undo),
            label: const Text('Undo this operation'),
          ),
        if (!applied) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: applying ? null : onReprepare,
            icon: const Icon(Icons.refresh),
            label: const Text('Rebuild plan'),
          ),
        ],
      ],
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
