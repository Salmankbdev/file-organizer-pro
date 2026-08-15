import 'category.dart';
import 'scanned_file.dart';

/// The result of a folder scan: the files found and aggregate statistics.
class ScanResult {
  const ScanResult({
    required this.folderPath,
    required this.scannedAt,
    required this.duration,
    required this.files,
    required this.errorCount,
  });

  final String folderPath;
  final DateTime scannedAt;
  final Duration duration;
  final List<ScannedFile> files;
  final int errorCount;

  int get fileCount => files.length;

  int get totalSize =>
      files.fold<int>(0, (sum, file) => sum + file.size);

  Map<FileCategory, List<ScannedFile>> get byCategory {
    final map = <FileCategory, List<ScannedFile>>{
      for (final c in FileCategory.values) c: <ScannedFile>[],
    };
    for (final f in files) {
      map[f.category]!.add(f);
    }
    return map;
  }

  /// Category -> number of files, serialized as JSON for persistence.
  Map<String, int> get categoryCountsJson => {
        for (final entry in byCategory.entries)
          entry.key.name: entry.value.length,
      };
}
