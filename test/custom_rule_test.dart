import 'package:file_organizer_pro/models/custom_rule.dart';
import 'package:file_organizer_pro/models/scanned_file.dart';
import 'package:flutter_test/flutter_test.dart';

ScannedFile file(String name) => ScannedFile(
      path: 'C:/test/$name',
      name: name,
      extension: name.contains('.')
          ? name.split('.').last.toLowerCase()
          : '',
      size: 100,
      modified: DateTime(2026, 8, 15),
    );

void main() {
  group('CustomRule.matches', () {
    test('extension is rule matches pdf files', () {
      final rule = CustomRule(
        name: 'PDFs',
        field: RuleField.extension,
        condition: RuleCondition.is_,
        value: '.pdf',
        targetFolder: 'Documents/PDF',
      );
      expect(rule.matches(file('report.pdf')), isTrue);
      expect(rule.matches(file('photo.jpg')), isFalse);
    });

    test('extension match ignores case and leading dot', () {
      final rule = CustomRule(
        name: 'PDFs',
        field: RuleField.extension,
        condition: RuleCondition.is_,
        value: 'PDF',
        targetFolder: 'Documents/PDF',
      );
      expect(rule.matches(file('Report.PDF')), isTrue);
    });

    test('filename contains rule', () {
      final rule = CustomRule(
        name: 'Invoices',
        field: RuleField.name,
        condition: RuleCondition.contains,
        value: 'invoice',
        targetFolder: 'Documents/Invoices',
      );
      expect(rule.matches(file('invoice_2026.pdf')), isTrue);
      expect(rule.matches(file('report.pdf')), isFalse);
    });

    test('filename startsWith / endsWith / is', () {
      final starts = CustomRule(
        name: 'IMG',
        field: RuleField.name,
        condition: RuleCondition.startsWith,
        value: 'IMG_',
        targetFolder: 'Photos',
      );
      expect(starts.matches(file('IMG_001.jpg')), isTrue);
      expect(starts.matches(file('photo_IMG.jpg')), isFalse);

      final ends = CustomRule(
        name: 'Backup',
        field: RuleField.name,
        condition: RuleCondition.endsWith,
        value: '.txt',
        targetFolder: 'Backups',
      );
      expect(ends.matches(file('notes_bak.txt')), isTrue);
      expect(ends.matches(file('photo.jpg')), isFalse);

      final exact = CustomRule(
        name: 'Readme',
        field: RuleField.name,
        condition: RuleCondition.is_,
        value: 'readme.md',
        targetFolder: 'Docs',
      );
      expect(exact.matches(file('readme.md')), isTrue);
      expect(exact.matches(file('readme_copy.md')), isFalse);
    });

    test('extension rule only honours the is condition', () {
      final rule = CustomRule(
        name: 'PDFs',
        field: RuleField.extension,
        condition: RuleCondition.contains,
        value: 'df',
        targetFolder: 'Documents/PDF',
      );
      // A `contains` condition on an extension never matches.
      expect(rule.matches(file('report.pdf')), isFalse);
    });
  });
}
