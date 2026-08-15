import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/duplicate_group.dart';
import '../models/scanned_file.dart';
import '../models/scan_result.dart';

/// Finds duplicate files: groups files by size first, then hashes the
/// candidates so only files whose contents are truly identical are reported.
class DuplicateService {
  const DuplicateService();

  /// Returns groups of files sharing identical content.
  ///
  /// [onProgress] reports (hashedSoFar, totalToHash) so the UI can show a
  /// determinate progress bar.
  Future<List<DuplicateGroup>> find(
    ScanResult scan, {
    void Function(int done, int total)? onProgress,
  }) async {
    // 1. Group by size — files of different sizes can't be duplicates.
    final bySize = <int, List<ScannedFile>>{};
    for (final file in scan.files) {
      bySize.putIfAbsent(file.size, () => []).add(file);
    }

    // 2. Hash candidates (size groups with more than one file).
    final candidates = <ScannedFile>[];
    for (final group in bySize.values) {
      if (group.length > 1) candidates.addAll(group);
    }

    final byHash = <String, List<ScannedFile>>{};
    var done = 0;
    for (final file in candidates) {
      try {
        final digest = await sha256Of(file.path);
        byHash.putIfAbsent(digest, () => []).add(file);
      } catch (_) {
        // Unreadable files are skipped, mirroring the scanner's behavior.
      }
      done++;
      onProgress?.call(done, candidates.length);
    }

    final groups = <DuplicateGroup>[];
    for (final entry in byHash.entries) {
      if (entry.value.length < 2) continue;
      groups.add(DuplicateGroup(
        hash: entry.key,
        size: entry.value.first.size,
        files: entry.value,
      ));
    }
    groups.sort((a, b) => b.size.compareTo(a.size));
    return groups;
  }

  /// SHA-256 hex digest of a file's contents.
  static Future<String> sha256Of(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
