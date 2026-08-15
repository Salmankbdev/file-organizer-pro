import 'dart:io';

import 'package:file_organizer_pro/models/scanned_file.dart';
import 'package:file_organizer_pro/services/organizer_service.dart';
import 'package:file_organizer_pro/services/rename_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late List<ScannedFile> files;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fop_rename_test_');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  ScannedFile scanned(String name, {String? content}) {
    final file = File(p.join(temp.path, name));
    if (!file.existsSync()) {
      file.writeAsStringSync(content ?? name);
    }
    return ScannedFile(
      path: file.path,
      name: name,
      extension: p.extension(name).replaceFirst('.', ''),
      size: file.lengthSync(),
      modified: file.statSync().modified,
    );
  }

  List<String> dirNames() => temp
      .listSync()
      .whereType<File>()
      .map((f) => p.basename(f.path))
      .toList()
    ..sort();

  group('plan building', () {
    test('find & replace derives names and skips no-ops', () {
      files = [scanned('a.txt'), scanned('b.txt')];
      final plan = const RenameService().buildPlan(
        files,
        const RenameOptions(find: 'a', replace: 'x'),
      );
      expect(plan.renames.length, 1);
      expect(plan.renames.first.newName, 'x.txt');
    });

    test('replace respects case sensitivity', () {
      files = [scanned('Photo.jpg')];
      final service = const RenameService();
      final strict = service.buildPlan(
        files,
        const RenameOptions(find: 'photo', replace: 'pic', caseSensitive: true),
      );
      expect(strict.renames, isEmpty);
      final loose = service.buildPlan(
        files,
        const RenameOptions(find: 'photo', replace: 'pic'),
      );
      expect(loose.renames.single.newName, 'pic.jpg');
    });

    test('replaceAll vs replaceFirst', () {
      files = [scanned('a1a.txt')];
      final service = const RenameService();
      final all = service.buildPlan(
        files,
        const RenameOptions(find: 'a', replace: 'b', replaceAll: true),
      );
      expect(all.renames.single.newName, 'b1b.txt');
      final first = service.buildPlan(
        files,
        const RenameOptions(find: 'a', replace: 'b', replaceAll: false),
      );
      expect(first.renames.single.newName, 'b1a.txt');
    });

    test('prefix and suffix modes', () {
      files = [scanned('report.pdf')];
      final service = const RenameService();
      expect(
        service
            .buildPlan(files, const RenameOptions(mode: RenameMode.prefix, prefix: 'Draft_'))
            .renames
            .single
            .newName,
        'Draft_report.pdf',
      );
      expect(
        service
            .buildPlan(files, const RenameOptions(mode: RenameMode.suffix, suffix: '_final'))
            .renames
            .single
            .newName,
        'report_final.pdf',
      );
    });

    test('numbering with start and padding', () {
      files = [scanned('b.jpg'), scanned('a.jpg')];
      final plan = const RenameService().buildPlan(
        files,
        const RenameOptions(
          mode: RenameMode.numbering,
          prefix: 'IMG_',
          startAt: 5,
          padding: 3,
        ),
      );
      // Ordered by input order, not sorted.
      expect(plan.renames.map((r) => r.newName), ['IMG_005.jpg', 'IMG_006.jpg']);
    });

    test('case modes', () {
      files = [scanned('hello world.TXT')];
      final service = const RenameService();
      expect(
        service
            .buildPlan(files, const RenameOptions(mode: RenameMode.case_))
            .renames
            .single
            .newName,
        'hello world.txt',
      );
      expect(
        service
            .buildPlan(
                files,
                const RenameOptions(
                    mode: RenameMode.case_, caseMode: CaseMode.title))
            .renames
            .single
            .newName,
        'Hello World.txt',
      );
    });
  });

  group('apply', () {
    test('renames files in place, skipping no-ops', () async {
      files = [scanned('a.txt'), scanned('b.txt')];
      final plan = const RenameService()
          .buildPlan(files, const RenameOptions(find: 'a', replace: 'x'));
      final result = await const RenameService().apply(plan);
      expect(result.renamed, 1);
      // No-ops never reach apply — buildPlan filters them out.
      expect(result.skipped, 0);
      expect(dirNames(), ['b.txt', 'x.txt']);
    });

    test('never overwrites on-disk conflicts', () async {
      scanned('b.txt', content: 'original-b');
      scanned('b (1).txt', content: 'candidate');
      files = [scanned('b (1).txt')];
      final plan = const RenameService().buildPlan(
        files,
        const RenameOptions(find: ' (1)', replace: ''),
      );
      final result = await const RenameService().apply(plan);
      expect(result.renamed, 1);
      expect(dirNames(), ['b (2).txt', 'b.txt']);
      expect(File(p.join(temp.path, 'b.txt')).readAsStringSync(), 'original-b');
      expect(
          File(p.join(temp.path, 'b (2).txt')).readAsStringSync(), 'candidate');
    });

    test('resolves collisions within the batch without data loss', () async {
      // 'a.txt' and 'aa.txt' both derive '.txt' — a genuine in-batch clash.
      final a = scanned('a.txt', content: 'first');
      final b = scanned('aa.txt', content: 'second');
      files = [a, b];
      final plan = const RenameService().buildPlan(
        files,
        const RenameOptions(find: 'a', replace: ''),
      );
      expect(plan.renames.length, 2);
      final result = await const RenameService().apply(plan);
      expect(result.renamed, 2);
      final names = dirNames().toSet();
      // With no real extension, the conflict suffix lands at the end,
      // matching the organizer's conflict convention.
      expect(names, {'.txt', '.txt (1)'});
      final contents = <String>{
        for (final f in temp.listSync().whereType<File>()) f.readAsStringSync(),
      };
      expect(contents, {'first', 'second'});
    });

    test('apply then undo restores original names and contents', () async {
      final a = scanned('report.pdf', content: 'payload-a');
      final b = scanned('notes.txt', content: 'payload-b');
      files = [a, b];
      final service = const RenameService();
      final plan = service.buildPlan(
        files,
        const RenameOptions(mode: RenameMode.prefix, prefix: 'Draft_'),
      );
      final result = await service.apply(plan);
      expect(result.renamed, 2);
      expect(dirNames(), ['Draft_notes.txt', 'Draft_report.pdf']);

      // Persist a batch exactly as the controller would.
      final ops = service.buildOperations(
        batchId: 1,
        plan: plan,
        appliedPaths: result.appliedPaths,
      );
      expect(ops.every((op) => op.action == 'rename'), isTrue);

      // Undo = move each file back to its original path.
      final undone = await const OrganizerService().undo(ops);
      expect(undone.undone, 2);
      expect(dirNames(), ['notes.txt', 'report.pdf']);
      expect(File(a.path).readAsStringSync(), 'payload-a');
      expect(File(b.path).readAsStringSync(), 'payload-b');
    });
  });
}
