import 'scanned_file.dart';

/// A set of files whose contents are byte-identical (same SHA-256).
class DuplicateGroup {
  const DuplicateGroup({
    required this.hash,
    required this.size,
    required this.files,
  });

  /// SHA-256 digest of the shared content.
  final String hash;

  /// Size in bytes of each file in the group.
  final int size;

  final List<ScannedFile> files;

  /// Total space one copy would free (all but one file).
  int get wastedBytes => size * (files.length - 1);
}
