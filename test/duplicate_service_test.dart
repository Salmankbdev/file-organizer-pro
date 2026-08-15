import 'dart:io';

import 'package:file_organizer_pro/models/scanned_file.dart';
import 'package:file_organizer_pro/models/scan_result.dart';
import 'package:file_organizer_pro/services/duplicate_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  final service = const DuplicateService();

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fop_dup_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  ScanResult scanOf(List<ScannedFile> files) => ScanResult(
        folderPath: temp.path,
        scannedAt: DateTime(2026, 8, 15),
        duration: Duration.zero,
        files: files,
        errorCount: 0,
      );

  Future<ScannedFile> write(String name, String content) async {
    final f = File('${temp.path}${Platform.pathSeparator}$name');
    await f.writeAsString(content);
    final stat = await f.stat();
    return ScannedFile(
      path: f.path,
      name: name,
      extension: name.split('.').last,
      size: stat.size,
      modified: stat.modified,
    );
  }

  test('groups identical files and ignores unique content', () async {
    final a = await write('a.txt', 'hello world');
    final b = await write('b.txt', 'hello world');
    final c = await write('c.txt', 'different content');
    final d = await write('d.jpg', 'hello world');

    final groups = await service.find(scanOf([a, b, c, d]));
    expect(groups, hasLength(1));
    expect(groups.single.files, hasLength(3));
    expect(groups.single.wastedBytes, groups.single.size * 2);
  });

  test('reports no duplicates when all contents differ', () async {
    final a = await write('a.txt', 'aaa');
    final b = await write('b.txt', 'bbb');
    final c = await write('c.txt', 'ccc');
    final groups = await service.find(scanOf([a, b, c]));
    expect(groups, isEmpty);
  });

  test('files with the same size but different content are not grouped',
      () async {
    final a = await write('a.txt', '0123456789');
    final b = await write('b.txt', 'abcdefghij');
    final groups = await service.find(scanOf([a, b]));
    expect(groups, isEmpty);
  });

  test('sha256Of is stable', () async {
    final a = await write('a.bin', 'stable content');
    final b = await write('b.bin', 'stable content');
    expect(await DuplicateService.sha256Of(a.path),
        await DuplicateService.sha256Of(b.path));
  });
}
