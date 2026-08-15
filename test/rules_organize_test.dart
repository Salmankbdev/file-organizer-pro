import 'dart:io';

import 'package:file_organizer_pro/models/custom_rule.dart';
import 'package:file_organizer_pro/models/scanned_file.dart';
import 'package:file_organizer_pro/models/scan_result.dart';
import 'package:file_organizer_pro/services/organizer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

ScannedFile file(String path) {
  final name = path.split('/').last;
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return ScannedFile(
    path: 'C:/demo/$path',
    name: name,
    extension: ext,
    size: 100,
    modified: DateTime(2026, 8, 15),
  );
}

ScanResult scan(List<String> paths) => ScanResult(
      folderPath: 'C:/demo',
      scannedAt: DateTime(2026, 8, 15),
      duration: Duration.zero,
      files: [for (final p in paths) file(p)],
      errorCount: 0,
    );

void main() {
  const organizer = OrganizerService();

  test('rules override the category destination', () {
    const rule = CustomRule(
      name: 'Invoices',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'Documents/Invoices',
    );
    final plan = organizer.buildPlan(
      scan(['invoice_2026.pdf', 'photo.jpg', 'main.dart']),
      rules: const [rule],
    );
    final invoiceMove =
        plan.moves.firstWhere((m) => m.file.name == 'invoice_2026.pdf');
    expect(invoiceMove.targetPath,
        p.join('C:/demo', 'Documents/Invoices', 'invoice_2026.pdf'));
  });

  test('disabled rules are ignored', () {
    const rule = CustomRule(
      name: 'Invoices',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'Documents/Invoices',
      enabled: false,
    );
    final plan = organizer.buildPlan(
      scan(['invoice_2026.pdf']),
      rules: const [rule],
    );
    // Falls back to the Documents category folder.
    expect(plan.moves.single.targetPath,
        p.join('C:/demo', 'Documents', 'invoice_2026.pdf'));
  });

  test('files already in the rule target folder are not moved again', () {
    const rule = CustomRule(
      name: 'Invoices',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'Documents/Invoices',
    );
    final plan = organizer.buildPlan(
      scan(['Documents/Invoices/invoice_2026.pdf']),
      rules: const [rule],
    );
    expect(plan.moves, isEmpty);
  });

  test('first matching rule wins', () {
    const rule = CustomRule(
      name: 'Everything to backup',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'Backups',
    );
    const other = CustomRule(
      name: 'Invoices',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'Documents/Invoices',
    );
    final plan = organizer.buildPlan(
      scan(['invoice_2026.pdf']),
      rules: const [rule, other],
    );
    expect(plan.moves.single.targetPath,
        p.join('C:/demo', 'Backups', 'invoice_2026.pdf'));
  });

  test('absolute rule targets are used as-is', () {
    const rule = CustomRule(
      name: 'Invoices',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'D:/Invoices',
    );
    final plan = organizer.buildPlan(
      scan(['invoice_2026.pdf']),
      rules: const [rule],
    );
    expect(plan.moves.single.targetPath,
        p.join('D:/Invoices', 'invoice_2026.pdf'));
  });

  test('createFolder=false falls through to category when folder is missing',
      () {
    const rule = CustomRule(
      name: 'Invoices',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'Documents/Invoices',
      createFolder: false,
    );
    final plan = organizer.buildPlan(
      scan(['invoice_2026.pdf']),
      rules: const [rule],
    );
    // Target doesn't exist, so the rule is skipped and the default category
    // folder is used instead.
    expect(plan.moves.single.targetPath,
        p.join('C:/demo', 'Documents', 'invoice_2026.pdf'));
  });

  test('createFolder=false applies when the target folder already exists',
      () async {
    final temp = await Directory.systemTemp.createTemp('fop_rule_test');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final target = Directory(p.join(temp.path, 'Documents', 'Invoices'));
    await target.create(recursive: true);

    const rule = CustomRule(
      name: 'Invoices',
      field: RuleField.name,
      condition: RuleCondition.contains,
      value: 'invoice',
      targetFolder: 'Documents/Invoices',
      createFolder: false,
    );
    final plan = organizer.buildPlan(
      ScanResult(
        folderPath: temp.path,
        scannedAt: DateTime(2026, 8, 15),
        duration: Duration.zero,
        files: [
          ScannedFile(
            path: p.join(temp.path, 'invoice_2026.pdf'),
            name: 'invoice_2026.pdf',
            extension: 'pdf',
            size: 10,
            modified: DateTime(2026, 8, 15),
          ),
        ],
        errorCount: 0,
      ),
      rules: const [rule],
    );
    // Implementation joins the scan root with the rule's relative target,
    // so build the expectation the same way.
    expect(plan.moves.single.targetPath,
        p.join(temp.path, 'Documents/Invoices', 'invoice_2026.pdf'));
  });

  test('protected system targets are detected', () {
    expect(
        OrganizerService.isProtectedTarget(r'C:\Windows\System32'), isTrue);
    expect(OrganizerService.isProtectedTarget(r'D:\Invoices'), isFalse);
    expect(
        OrganizerService.isProtectedTarget(
            r'C:\Program Files (x86)\App'),
        isTrue);
  });
}

