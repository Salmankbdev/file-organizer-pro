import 'dart:io';

import 'package:file_organizer_pro/services/cache_cleaner.dart';
import 'package:file_organizer_pro/services/demo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fop_cache_test_');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  group('DemoService folder helpers', () {
    test('folderBytes counts nested files and ignores missing folders', () async {
      // Missing folder → 0.
      expect(await DemoService.folderBytes(p.join(temp.path, 'nope')), 0);

      await File(p.join(temp.path, 'a.bin')).writeAsBytes(List.filled(10, 1));
      final sub = Directory(p.join(temp.path, 'sub'));
      await sub.create();
      await File(p.join(sub.path, 'b.bin')).writeAsBytes(List.filled(25, 2));

      expect(await DemoService.folderBytes(temp.path), 35);
    });

    test('deleteFolder removes the tree and reports existence', () async {
      final sub = Directory(p.join(temp.path, 'sub'));
      await sub.create(recursive: true);
      await File(p.join(sub.path, 'f.txt')).writeAsString('x');

      expect(await DemoService.deleteFolder(p.join(temp.path, 'missing')),
          isFalse);
      expect(await DemoService.deleteFolder(temp.path), isTrue);
      expect(await temp.exists(), isFalse);
    });
  });

  group('CacheCleaner math', () {
    test('computeFreedBytes is the positive before-minus-after delta', () {
      expect(computeFreedBytes(5000, 1200), 3800);
      expect(computeFreedBytes(5000, 5000), 0);
    });

    test('computeFreedBytes clamps at zero when nothing was freed', () {
      expect(computeFreedBytes(100, 250), 0);
      expect(computeFreedBytes(0, 10), 0);
    });

    test('CacheSnapshot total is db + demo bytes', () {
      const snap = CacheSnapshot(
        scanCount: 3,
        scanPayloadBytes: 100,
        dbBytes: 200,
        demoBytes: 50,
      );
      expect(snap.totalBytes, 250);
      expect(snap.isEmpty, isFalse);

      const empty = CacheSnapshot(
        scanCount: 0,
        scanPayloadBytes: 0,
        dbBytes: 0,
        demoBytes: 0,
      );
      expect(empty.isEmpty, isTrue);
    });

    test('CacheCleanResult flags whether anything was freed', () {
      const freed = CacheCleanResult(
        scanSummariesCleared: 4,
        demoFolderRemoved: true,
        bytesFreed: 1024,
      );
      expect(freed.freedNothing, isFalse);

      const none = CacheCleanResult(
        scanSummariesCleared: 0,
        demoFolderRemoved: false,
        bytesFreed: 0,
      );
      expect(none.freedNothing, isTrue);
    });
  });
}
