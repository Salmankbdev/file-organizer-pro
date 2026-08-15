import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../models/custom_rule.dart';
import '../widgets/common.dart';

/// Manages user-defined organization rules (create / edit / delete /
/// enable / disable / test).
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final rules = controller.rules;

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
                    child: Text('Custom Rules',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('New rule'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Rules are checked before the default category mapping when '
                'you organize a folder. Example: filename contains "invoice" '
                '→ Documents/Invoices.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              if (rules.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.rule_outlined,
                    title: 'No rules yet',
                    message:
                        'Create a rule to send matching files to a custom '
                        'folder, like "invoice" → Documents/Invoices.',
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      for (final rule in rules)
                        _RuleCard(
                          rule: rule,
                          onToggle: (v) => controller.toggleRule(rule, v),
                          onEdit: () =>
                              _openEditor(context, controller, rule: rule),
                          onDelete: () => _confirmDelete(context, controller, rule),
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

  Future<void> _confirmDelete(
      BuildContext context, AppController controller, CustomRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('"${rule.name}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && rule.id != null) {
      await controller.deleteRule(rule.id!);
    }
  }

  Future<void> _openEditor(BuildContext context, AppController controller,
      {CustomRule? rule}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _RuleEditorDialog(
        controller: controller,
        rule: rule,
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          rule.enabled ? Icons.rule : Icons.rule_outlined,
          color: rule.enabled ? scheme.primary : scheme.outline,
        ),
        title: Text(rule.name,
            style: TextStyle(
                color: rule.enabled ? null : scheme.onSurfaceVariant)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IF ${rule.field.label.toLowerCase()} '
              '${rule.condition.label} "${rule.value}" '
              'THEN move to ${rule.targetFolder}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (!rule.enabled)
              Text('Disabled', style: TextStyle(color: scheme.outline)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: rule.enabled, onChanged: onToggle),
            IconButton(
              tooltip: 'Test rule',
              icon: const Icon(Icons.science_outlined),
              onPressed: () => _testRule(context),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _testRule(BuildContext context) {
    final controller = AppScope.of(context);
    final scan = controller.currentScan;
    final matches = scan == null
        ? 0
        : scan.files.where(rule.matches).length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(scan == null
          ? 'Run a scan first to test this rule.'
          : '"${rule.name}" matches $matches file(s) in the latest scan.'),
    ));
  }
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({required this.controller, this.rule});

  final AppController controller;
  final CustomRule? rule;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _value;
  late final TextEditingController _target;
  late RuleField _field;
  late RuleCondition _condition;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _name = TextEditingController(text: rule?.name ?? '');
    _value = TextEditingController(text: rule?.value ?? '');
    _target = TextEditingController(text: rule?.targetFolder ?? '');
    _field = rule?.field ?? RuleField.name;
    _condition = rule?.condition ?? RuleCondition.contains;
  }

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final value = _value.text.trim();
    final target = _target.text.trim().replaceAll(RegExp(r'[\\/]+'), '/');
    if (name.isEmpty || value.isEmpty || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name, match value and target folder are required.')));
      return;
    }
    final base = widget.rule;
    await widget.controller.saveRule(CustomRule(
      id: base?.id,
      name: name,
      field: _field,
      condition: _condition,
      value: value,
      targetFolder: target,
      enabled: base?.enabled ?? true,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule == null ? 'New rule' : 'Edit rule'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Rule name',
                  hintText: 'e.g. Invoice files',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<RuleField>(
                      initialValue: _field,
                      decoration: const InputDecoration(
                        labelText: 'IF file',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final f in RuleField.values)
                          DropdownMenuItem(value: f, child: Text(f.label)),
                      ],
                      onChanged: (v) => setState(() {
                        _field = v ?? RuleField.name;
                        if (_field == RuleField.extension) {
                          _condition = RuleCondition.is_;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<RuleCondition>(
                      initialValue: _condition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in RuleCondition.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: _field == RuleField.extension
                          ? null
                          : (v) => setState(() =>
                              _condition = v ?? RuleCondition.contains),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                decoration: InputDecoration(
                  labelText: _field == RuleField.extension
                      ? 'Extension (e.g. pdf)'
                      : 'Match text (e.g. invoice)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _target,
                decoration: const InputDecoration(
                  labelText: 'Move to folder (relative)',
                  hintText: 'e.g. Documents/Invoices',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save rule'),
        ),
      ],
    );
  }
}
