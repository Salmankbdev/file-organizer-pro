import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/file_utils.dart';
import '../models/move_operation.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _undoing = false;

  Future<void> _undoLast(AppController controller) async {
    setState(() => _undoing = true);
    final message = await controller.undoLast();
    if (mounted) {
      setState(() => _undoing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message ?? 'Nothing to undo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final history = controller.history;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Operation History',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _undoing || history.isEmpty
                        ? null
                        : () => _undoLast(controller),
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo Last Operation'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Every move is recorded here and can be reversed — '
                '${controller.organizedFileCount} organize move(s) currently in effect.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              if (history.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.history_toggle_off,
                    title: 'No operations yet',
                    message:
                        'Organize a folder and its moves will appear here, '
                        'ready to be undone.',
                  ),
                )
              else
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('When')),
                                DataColumn(label: Text('File')),
                                DataColumn(label: Text('From → To')),
                                DataColumn(label: Text('Action')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: [
                                for (final op in history)
                                  _operationRow(context, op),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _operationRow(BuildContext context, MoveOperation op) {
    final scheme = Theme.of(context).colorScheme;
    final isUndo = op.action == 'undo' || op.action == 'extract_undo';
    final isExtract = op.action == 'extract';
    final failed = op.status == 'failed';
    final actionColor =
        failed ? scheme.error : (isUndo ? scheme.tertiary : scheme.primary);
    final (icon, label) = isExtract
        ? (Icons.unarchive_outlined, 'Extract')
        : (isUndo && op.action == 'extract_undo'
            ? (Icons.undo, 'Extract undo')
            : (isUndo
                ? (Icons.undo, 'Undo')
                : (Icons.drive_file_move, 'Organize')));
    return DataRow(cells: [
      DataCell(Text(FileUtils.humanDate(op.createdAt))),
      DataCell(Text(op.fileName, overflow: TextOverflow.ellipsis, maxLines: 1)),
      DataCell(Text(
        '${_short(op.fromPath)} → ${_short(op.toPath)}',
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      )),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: actionColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: actionColor)),
        ],
      )),
      DataCell(Text(failed ? 'Failed' : 'Completed',
          style: TextStyle(
              color: failed ? scheme.error : scheme.onSurfaceVariant))),
    ]);
  }

  String _short(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return path;
    final last = list.last;
    return list.length >= 2 ? '…\\$last' : last;
  }
}
