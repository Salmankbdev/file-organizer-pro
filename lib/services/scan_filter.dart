import '../models/category.dart';
import '../models/scanned_file.dart';

/// Filters and sorts [all] by the given criteria.
///
/// Kept free of UI dependencies so it can run on a background isolate via
/// [Isolate.run] — filtering and sorting tens of thousands of files
/// synchronously on the UI isolate is what froze the app while typing.
List<ScannedFile> filterAndSortFiles(
  List<ScannedFile> all, {
  String query = '',
  FileCategory? category,
  double? minMb,
  double? maxMb,
  DateTime? from,
  DateTime? to,
  int? sortColumn,
  bool sortAscending = true,
}) {
  var files = all;
  if (category != null) {
    files = files.where((f) => f.category == category).toList();
  }
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    files = files
        .where((f) =>
            f.name.toLowerCase().contains(q) ||
            f.extension.toLowerCase().contains(q) ||
            f.path.toLowerCase().contains(q))
        .toList();
  }
  if (minMb != null) {
    final minBytes = (minMb * 1024 * 1024).round();
    files = files.where((f) => f.size >= minBytes).toList();
  }
  if (maxMb != null) {
    final maxBytes = (maxMb * 1024 * 1024).round();
    files = files.where((f) => f.size <= maxBytes).toList();
  }
  if (from != null) {
    files = files.where((f) => !f.modified.isBefore(from)).toList();
  }
  if (to != null) {
    final end = to.add(const Duration(days: 1));
    files = files.where((f) => f.modified.isBefore(end)).toList();
  }
  if (sortColumn != null) {
    files.sort((a, b) {
      int cmp;
      switch (sortColumn) {
        case 0:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 1:
          cmp = a.category.index.compareTo(b.category.index);
        case 2:
          cmp = a.size.compareTo(b.size);
        default:
          cmp = a.modified.compareTo(b.modified);
      }
      return sortAscending ? cmp : -cmp;
    });
  }
  return files;
}
