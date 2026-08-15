import 'dart:io';

import 'package:file_organizer_pro/models/category.dart';
import 'package:file_organizer_pro/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fop_scan_test_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> write(String relPath, List<int> bytes) async {
    final file = File('${temp.path}${Platform.pathSeparator}$relPath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  test('scans nested files, collecting name, extension, size, category', () async {
    await write('a.jpg', List.filled(100, 1));
    await write('sub/b.mp4', List.filled(200, 2));
    await write('sub/deep/c.pdf', List.filled(300, 3));
    await write('notes.txt', List.filled(50, 4));

    final progress = <int>[];
    final result = await const ScannerService().scan(
      temp.path,
      onProgress: (files, bytes) => progress.add(files),
    );

    expect(result.fileCount, 4);
    expect(result.totalSize, 650);
    expect(result.errorCount, 0);
    expect(progress.last, 4);

    final byName = {for (final f in result.files) f.name: f};
    expect(byName['a.jpg']!.extension, 'jpg');
    expect(byName['a.jpg']!.category, FileCategory.images);
    expect(byName['b.mp4']!.category, FileCategory.videos);
    expect(byName['c.pdf']!.category, FileCategory.documents);
    expect(byName['notes.txt']!.category, FileCategory.documents);
  });

  test('ignores directories and counts unreadable entries as errors', () async {
    await write('ok.png', [1, 2, 3]);
    await Directory('${temp.path}${Platform.pathSeparator}empty').create();

    final result = await const ScannerService().scan(temp.path);
    expect(result.fileCount, 1);
    expect(result.errorCount, 0);
  });

  test('handles an empty folder', () async {
    final result = await const ScannerService().scan(temp.path);
    expect(result.fileCount, 0);
    expect(result.totalSize, 0);
    expect(result.duration, isNot(Duration.zero));
  });

  test('reports progress bytes', () async {
    await write('one.bin', List.filled(10, 1));
    await write('two.bin', List.filled(20, 2));

    var seen = 0;
    await const ScannerService().scan(temp.path,
        onProgress: (files, bytes) => seen = bytes);
    expect(seen, 30);
  });
}
