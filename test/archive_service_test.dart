import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_organizer_pro/models/scanned_file.dart';
import 'package:file_organizer_pro/models/scan_result.dart';
import 'package:file_organizer_pro/services/archive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  final service = const ArchiveService();

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fop_archive_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> write(String rel, List<int> bytes) async {
    final f = File(p.join(temp.path, rel));
    await f.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<ScannedFile> scanned(File f) async {
    final stat = await f.stat();
    return ScannedFile(
      path: f.path,
      name: p.basename(f.path),
      extension: p.extension(f.path).replaceFirst('.', '').toLowerCase(),
      size: stat.size,
      modified: stat.modified,
    );
  }

  ScanResult resultOf(List<ScannedFile> files) => ScanResult(
        folderPath: temp.path,
        scannedAt: DateTime(2026, 8, 15),
        duration: Duration.zero,
        files: files,
        errorCount: 0,
      );

  List<int> makeZip(List<(String, List<int>)> entries) {
    final archive = Archive();
    for (final (name, bytes) in entries) {
      archive.addFile(ArchiveFile.bytes(name, bytes));
    }
    return ZipEncoder().encode(archive);
  }

  test('buildPlan skips non-extractable files and already-extracted ones',
      () async {
    final zip = await write('backup.zip', makeZip([('a.txt', utf8.encode('a'))]));
    final rar = await write('old.rar', utf8.encode('nope'));
    final done = await write(
        'Extracted/backup/a.txt', utf8.encode('already here'));

    final plan = service.buildPlan(resultOf([
      await scanned(zip),
      await scanned(rar),
      await scanned(done),
    ]));
    expect(plan, hasLength(1));
    expect(plan.single.file.name, 'backup.zip');
    expect(plan.single.targetDir,
        p.join(temp.path, 'Extracted', 'backup'));
  });

  test('extracts a zip with nested folders and reports created paths',
      () async {
    final zipFile = await write(
        'docs.zip',
        makeZip([
          ('readme.txt', utf8.encode('hello')),
          ('sub/notes.txt', utf8.encode('nested')),
        ]));
    final entry = const ArchiveService().buildPlan(
      resultOf([await scanned(zipFile)]),
    ).single;

    final result = await service.extract([entry]);
    expect(result.failed, 0);
    expect(result.filesWritten, 2);
    expect(await File(p.join(entry.targetDir, 'readme.txt')).readAsString(),
        'hello');
    expect(
        await File(p.join(entry.targetDir, 'sub', 'notes.txt'))
            .readAsString(),
        'nested');
    // Undo removes the files and the empty folders.
    final allFiles = result.createdFiles.values.expand((f) => f).toList();
    final removed = await ArchiveService.undoCleanup(
        allFiles, result.createdDirs);
    expect(removed, 2);
    expect(await Directory(entry.targetDir).exists(), isFalse);
  });

  test('refuses path traversal entries (../)', () async {
    final zipFile = await write(
        'evil.zip',
        makeZip([
          ('../evil.txt', utf8.encode('pwned')),
          ('ok.txt', utf8.encode('fine')),
        ]));
    final entry = service.buildPlan(resultOf([await scanned(zipFile)])).single;

    final result = await service.extract([entry]);
    expect(result.filesWritten, 1);
    expect(
        await File(p.join(temp.path, 'evil.txt')).exists(), isFalse);
    expect(
        await File(p.join(entry.targetDir, 'ok.txt')).exists(), isTrue);
  });

  test('never overwrites existing files — uses a (1) suffix', () async {
    final zipFile = await write(
        'conflict.zip',
        makeZip([('data.txt', utf8.encode('from zip'))]));
    final entry = service.buildPlan(resultOf([await scanned(zipFile)])).single;
    await write(p.join('Extracted', 'conflict', 'data.txt'), utf8.encode('old'));

    final result = await service.extract([entry]);
    expect(result.filesWritten, 1);
    expect(
        await File(p.join(entry.targetDir, 'data.txt')).readAsString(), 'old');
    expect(
        await File(p.join(entry.targetDir, 'data (1).txt')).readAsString(),
        'from zip');
  });

  test('extracts plain .gz files', () async {
    final gzBytes = GZipEncoder().encode(utf8.encode('compressed content'));
    final gzFile = await write('log.txt.gz', gzBytes);
    final entry = service.buildPlan(resultOf([await scanned(gzFile)])).single;

    final result = await service.extract([entry]);
    expect(result.filesWritten, 1);
    // Content is written under the gzip-stored name (log.txt) inside target.
    final created = result.createdFiles.values.expand((f) => f).toList();
    expect(created, hasLength(1));
    expect(await File(created.single).readAsString(), 'compressed content');
  });

  test('extracts tar and tar.gz archives', () async {
    final tar = Archive();
    tar.addFile(ArchiveFile.bytes('t.txt', utf8.encode('t')));
    final tarBytes = TarEncoder().encode(tar);
    final tarFile = await write('bundle.tar', tarBytes);

    final tgzBytes = GZipEncoder().encode(TarEncoder().encode(tar));
    final tgzFile = await write('bundle.tar.gz', tgzBytes);

    final plan = service.buildPlan(
      resultOf([await scanned(tarFile), await scanned(tgzFile)]),
    );
    final result = await service.extract(plan);
    expect(result.filesWritten, 2);
    expect(await File(p.join(temp.path, 'Extracted', 'bundle', 't.txt'))
            .readAsString(),
        't');
    expect(
        await File(
                p.join(temp.path, 'Extracted', 'bundle', 't.txt'))
            .readAsString(),
        't');
  });

  test('reports progress as archives complete', () async {
    final zipFile = await write(
        'multi.zip', makeZip([('a.txt', utf8.encode('a'))]));
    final entry = service.buildPlan(resultOf([await scanned(zipFile)])).single;
    final calls = <(int, int)>[];
    await service.extract([entry], onProgress: (d, t, c) => calls.add((d, t)));
    expect(calls.first, (0, 1));
    expect(calls.last, (1, 1));
  });
}
