import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/scanned_file.dart';
import '../models/scan_result.dart';

/// A planned archive extraction.
class ExtractPlanEntry {
  const ExtractPlanEntry({
    required this.file,
    required this.targetDir,
  });

  final ScannedFile file;

  /// Absolute folder the archive's contents are unpacked into.
  final String targetDir;

  /// Friendly name, e.g. `backup.zip → backup/`.
  String get label => '${file.name} → ${p.basename(targetDir)}/';
}

/// The outcome of running an extraction plan.
class ExtractResult {
  const ExtractResult({
    required this.archives,
    required this.filesWritten,
    required this.failed,
    required this.createdFiles,
    required this.createdDirs,
  });

  final int archives;
  final int filesWritten;
  final int failed;

  /// Archive path -> final paths of the files it wrote.
  final Map<String, List<String>> createdFiles;

  /// Directories created during extraction (for undo cleanup).
  final List<String> createdDirs;
}

/// Safely unpacks zip / tar / gz archives into an `Extracted/` folder inside
/// the scanned root.
///
/// Safety guarantees:
/// - entry names are sanitized: `..`, absolute paths and symlinks are refused
/// - existing files are never overwritten — a unique `name (1).ext` is used
/// - nothing is ever written outside the per-archive target folder
class ArchiveService {
  const ArchiveService();

  /// Extensions the service can unpack with pure-Dart codecs.
  static const Set<String> supportedExtensions = {'zip', 'tar', 'gz', 'tgz'};

  bool isExtractable(ScannedFile file) =>
      supportedExtensions.contains(file.extension);

  /// Builds the extraction plan for [scan]: every extractable archive is
  /// unpacked into `<root>/Extracted/<archive-name>/`. Archives already
  /// living inside an `Extracted/` folder are skipped.
  List<ExtractPlanEntry> buildPlan(ScanResult scan) {
    const extractedDir = 'Extracted';
    final entries = <ExtractPlanEntry>[];
    for (final file in scan.files) {
      if (!isExtractable(file)) continue;
      final parent = _norm(File(file.path).parent.path);
      if (parent == _norm(p.join(scan.folderPath, extractedDir)) ||
          parent.startsWith('${_norm(p.join(scan.folderPath, extractedDir))}/')) {
        continue;
      }
      final baseName = _stripArchiveExtensions(file.name);
      entries.add(ExtractPlanEntry(
        file: file,
        targetDir: p.join(scan.folderPath, extractedDir, baseName),
      ));
    }
    return entries;
  }

  /// Extracts every entry, reporting per-archive progress. Returns the files
  /// and folders created so the operation can be undone later.
  Future<ExtractResult> extract(
    List<ExtractPlanEntry> entries, {
    void Function(int done, int total, String current)? onProgress,
  }) async {
    var filesWritten = 0, failed = 0;
    final createdFiles = <String, List<String>>{};
    final createdDirs = <String>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final currentLabel = entry.file.name;
      onProgress?.call(i, entries.length, currentLabel);
      try {
        final bytes = await File(entry.file.path).readAsBytes();
        final written = await _extractOne(bytes, entry, createdDirs);
        createdFiles[entry.file.path] = written;
        filesWritten += written.length;
      } catch (_) {
        failed++;
      }
      onProgress?.call(i + 1, entries.length, currentLabel);
    }

    return ExtractResult(
      archives: entries.length,
      filesWritten: filesWritten,
      failed: failed,
      createdFiles: createdFiles,
      createdDirs: createdDirs,
    );
  }

  /// Reverses an extraction: deletes the recorded files and then removes any
  /// of the recorded directories that ended up empty. Returns the number of
  /// files removed.
  static Future<int> undoCleanup(
    List<String> createdFiles,
    List<String> createdDirs,
  ) async {
    var removed = 0;
    for (final path in createdFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          removed++;
        }
      } catch (_) {
        // Continue with the remaining files.
      }
    }
    // Deepest-first so child folders empty out before their parents.
    final sorted = [...createdDirs]..sort((a, b) => b.length.compareTo(a.length));
    for (final dirPath in sorted) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final remaining = await dir.list().toList();
          if (remaining.isEmpty) await dir.delete();
        }
      } catch (_) {
        // Not empty (or locked) — leave it alone.
      }
    }
    return removed;
  }

  // --- internals ---------------------------------------------------------

  Future<List<String>> _extractOne(
    List<int> bytes,
    ExtractPlanEntry entry,
    List<String> createdDirs,
  ) async {
    final archive = _decode(bytes, entry.file.name);
    final written = <String>[];

    for (final item in archive.files) {
      if (!item.isFile || item.isSymbolicLink) continue;
      final safe = _safeRelativeName(item.name);
      if (safe == null) continue; // traversal attempt — refused
      final targetFile = p.join(entry.targetDir, safe);

      // Defense in depth: never allow an entry to resolve outside the target.
      if (!_isWithin(entry.targetDir, targetFile)) continue;

      final dir = p.dirname(targetFile);
      if (!createdDirs.contains(dir)) {
        await Directory(dir).create(recursive: true);
        createdDirs.add(dir);
      }

      var finalPath = targetFile;
      if (await File(finalPath).exists()) {
        finalPath = await _uniquePath(finalPath);
      }
      await File(finalPath).writeAsBytes(item.content, flush: true);
      written.add(finalPath);
    }
    return written;
  }

  Archive _decode(List<int> bytes, String name) {
    final ext = p.extension(name).toLowerCase();
    if (ext == '.zip') return ZipDecoder().decodeBytes(bytes);
    if (ext == '.tar') return TarDecoder().decodeBytes(bytes);
    // .gz decompresses to raw bytes; .tgz/.tar.gz wrap a tar stream.
    final gunzipped = GZipDecoder().decodeBytes(bytes);
    final isTarGz =
        name.toLowerCase().endsWith('.tar.gz') || ext == '.tgz';
    if (isTarGz) {
      return TarDecoder().decodeBytes(gunzipped);
    }
    // Plain .gz: one file named after the archive without its extension.
    final archive = Archive();
    final base = name.substring(0, name.length - ext.length);
    archive.addFile(ArchiveFile.bytes(base, gunzipped));
    return archive;
  }

  /// Strips archive extensions: `backup.tar.gz` -> `backup`, `a.zip` -> `a`.
  String _stripArchiveExtensions(String name) {
    var base = name;
    while (true) {
      final ext = p.extension(base).toLowerCase();
      if (ext == '.zip' || ext == '.tar' || ext == '.gz') {
        base = base.substring(0, base.length - ext.length);
      } else {
        break;
      }
    }
    return base;
  }

  /// Normalizes an entry name to a safe relative path, or returns null if it
  /// escapes the target (e.g. `../evil`, absolute paths, symlinks).
  String? _safeRelativeName(String raw) {
    var name = raw.replaceAll('\\', '/');
    while (name.startsWith('/')) {
      name = name.substring(1);
    }
    name = name.replaceFirst(RegExp(r'^[A-Za-z]:/'), '');
    if (name.isEmpty) return null;
    for (final segment in name.split('/')) {
      if (segment.isEmpty) continue;
      if (segment == '..') return null;
      if (segment.contains('\u0000')) return null;
    }
    return name;
  }

  bool _isWithin(String baseDir, String candidate) {
    final base = _norm(baseDir);
    final target = _norm(candidate);
    return target == base || target.startsWith('$base/');
  }

  Future<String> _uniquePath(String candidate) async {
    final dir = p.dirname(candidate);
    final base = p.basenameWithoutExtension(candidate);
    final ext = p.extension(candidate);
    var n = 1;
    while (true) {
      final next = p.join(dir, '$base ($n)$ext');
      if (!await File(next).exists()) return next;
      n++;
    }
  }

  String _norm(String path) => path.replaceAll('\\', '/').toLowerCase();
}
