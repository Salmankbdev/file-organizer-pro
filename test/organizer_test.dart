import 'dart:io';

import 'package:file_organizer_pro/models/scanned_file.dart';
import 'package:file_organizer_pro/models/scan_result.dart';
import 'package:file_organizer_pro/services/organizer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  const organizer = OrganizerService();

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fop_org_test_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> write(String relPath, [String content = 'x']) async {
    final file = File(p.join(temp.path, relPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  ScannedFile scanned(File file) => ScannedFile(
        path: file.path,
        name: p.basename(file.path),
        extension: p.extension(file.path).replaceFirst('.', '').toLowerCase(),
        size: 1,
        modified: DateTime.now(),
      );

  ScanResult scanOf(List<File> files) => ScanResult(
        folderPath: temp.path,
        scannedAt: DateTime.now(),
        duration: Duration.zero,
        files: files.map(scanned).toList(),
        errorCount: 0,
      );

  test('buildPlan moves known extensions into category folders', () async {
    final jpg = await write('photo.jpg');
    final pdf = await write('doc.pdf');
    await write('unknown.zzz');

    final plan = organizer.buildPlan(scanOf([jpg, pdf]));
    expect(plan.moves.length, 2);
    expect(
      plan.moves.any((m) => m.targetPath == p.join(temp.path, 'Images', 'photo.jpg')),
      isTrue,
    );
    expect(
      plan.moves.any((m) => m.targetPath == p.join(temp.path, 'Documents', 'doc.pdf')),
      isTrue,
    );
  });

  test('buildPlan skips files already inside their category folder', () async {
    final already = await write(p.join('Images', 'photo.jpg'));
    final loose = await write('audio.mp3');

    final plan = organizer.buildPlan(scanOf([already, loose]));
    expect(plan.moves.length, 1);
    expect(p.basename(plan.moves.first.file.path), 'audio.mp3');
  });

  test('apply creates folders and moves files', () async {
    final jpg = await write('photo.jpg');
    final mp4 = await write('clip.mp4');
    final plan = organizer.buildPlan(scanOf([jpg, mp4]));

    final result = await organizer.apply(plan, preventOverwrite: true);

    expect(result.moved, 2);
    expect(result.failed, 0);
    expect(await File(jpg.path).exists(), isFalse);
    expect(await File(p.join(temp.path, 'Images', 'photo.jpg')).exists(), isTrue);
    expect(await File(p.join(temp.path, 'Videos', 'clip.mp4')).exists(), isTrue);
    expect(result.appliedPaths[jpg.path],
        p.join(temp.path, 'Images', 'photo.jpg'));
  });

  test('apply resolves name conflicts with a numeric suffix', () async {
    final a = await write('photo.jpg');
    final b = await write(p.join('nested', 'photo.jpg'));

    final plan = organizer.buildPlan(scanOf([a, b]));
    final result = await organizer.apply(plan, preventOverwrite: true);

    expect(result.moved, 2);
    final movedPaths = result.appliedPaths.values.toList();
    expect(movedPaths, contains(p.join(temp.path, 'Images', 'photo.jpg')));
    expect(
      movedPaths,
      contains(p.join(temp.path, 'Images', 'photo (1).jpg')),
    );
    expect(await File(p.join(temp.path, 'Images', 'photo (1).jpg')).exists(),
        isTrue);
  });

  test('apply skips conflicts when overwriting is disabled', () async {
    final a = await write('photo.jpg');
    final b = await write(p.join('nested', 'photo.jpg'));

    final plan = organizer.buildPlan(scanOf([a, b]));
    final result = await organizer.apply(plan, preventOverwrite: false);

    expect(result.moved, 1);
    expect(result.skipped, 1);
    expect(await File(b.path).exists(), isTrue, reason: 'conflicting file untouched');
  });

  test('undo restores files to their original locations', () async {
    final jpg = await write('photo.jpg');
    final plan = organizer.buildPlan(scanOf([jpg]));
    await organizer.apply(plan, preventOverwrite: true);

    final batchId = 1;
    final ops = organizer.buildOperations(
      batchId: batchId,
      moves: plan.moves,
      appliedPaths: {
        jpg.path: p.join(temp.path, 'Images', 'photo.jpg'),
      },
    );

    final undo = await organizer.undo(ops);
    expect(undo.undone, 1);
    expect(await File(jpg.path).exists(), isTrue);
    expect(await File(p.join(temp.path, 'Images', 'photo.jpg')).exists(), isFalse);
  });

  test('buildOperations only records actually-applied moves', () async {
    final a = await write('photo.jpg');
    final b = await write('bogus.jpg');
    final plan = organizer.buildPlan(scanOf([a, b]));
    await organizer.apply(plan, preventOverwrite: false);

    final ops = organizer.buildOperations(
      batchId: 7,
      moves: plan.moves,
      appliedPaths: {a.path: p.join(temp.path, 'Images', 'photo.jpg')},
    );

    expect(ops.length, 1);
    expect(ops.first.batchId, 7);
    expect(ops.first.action, 'organize');
  });
}
