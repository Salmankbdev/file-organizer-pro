import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/scanned_file.dart';
import '../models/scan_result.dart';

/// Walks a folder recursively and collects file metadata.
class ScannerService {
  const ScannerService();

  /// Scans [rootPath] recursively, reporting progress via [onProgress]
  /// (files found so far, bytes seen so far). Errors (e.g. permission
  /// denied) are counted and skipped rather than aborting the scan.
  Future<ScanResult> scan(
    String rootPath, {
    void Function(int files, int bytes)? onProgress,
  }) async {
    final root = Directory(rootPath);
    final stopwatch = Stopwatch()..start();
    final files = <ScannedFile>[];
    var errorCount = 0;
    var bytesSeen = 0;

    await for (final entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        final name = p.basename(entity.path);
        files.add(ScannedFile(
          path: entity.path,
          name: name,
          extension: p.extension(name).replaceFirst('.', '').toLowerCase(),
          size: stat.size,
          modified: stat.modified,
        ));
        bytesSeen += stat.size;
        onProgress?.call(files.length, bytesSeen);
      } catch (_) {
        errorCount++;
      }
    }

    stopwatch.stop();
    return ScanResult(
      folderPath: rootPath,
      scannedAt: DateTime.now(),
      duration: stopwatch.elapsed,
      files: files,
      errorCount: errorCount,
    );
  }

  /// Paths of system folders that must never be reorganized.
  static const List<String> protectedRoots = [
    r'C:\Windows',
    r'C:\Program Files',
    r'C:\Program Files (x86)',
    r'C:\$Recycle.Bin',
    r'C:\System Volume Information',
    r'C:\ProgramData',
  ];

  /// True if [path] (or any ancestor) is a protected system folder.
  static bool isProtected(String path) {
    final normalized = path.replaceAll('/', r'\').toLowerCase();
    if (normalized.length <= 3) return true; // drive root or shorter
    for (final root in protectedRoots) {
      final candidate = root.toLowerCase();
      if (normalized == candidate ||
          normalized.startsWith('$candidate\\')) {
        return true;
      }
    }
    return false;
  }
}
