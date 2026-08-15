import 'dart:io';

import 'category.dart';

/// A single file discovered by a scan.
class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.size,
    required this.modified,
  });

  /// Absolute path to the file.
  final String path;

  /// File name including its extension.
  final String name;

  /// Extension without the leading dot, lower-cased.
  final String extension;

  /// File size in bytes.
  final int size;

  /// Last modification time.
  final DateTime modified;

  FileCategory get category => FileCategory.fromExtension(extension);

  /// Whether this file should be moved when the folder is organized.
  /// Files without a known extension, or already living inside their
  /// category folder, are considered already organized.
  bool needsOrganizing({required String categoryDir}) {
    if (category == FileCategory.other) return false;
    final parent = _norm(File(path).parent.path);
    final target = _norm(categoryDir);
    if (parent == target) return false;
    if (parent.startsWith('$target/')) return false;
    return true;
  }

  /// Lower-cases and normalizes separators so comparisons work regardless of
  /// whether paths use `/` or `\`.
  static String _norm(String path) =>
      path.replaceAll('\\', '/').toLowerCase();
}
