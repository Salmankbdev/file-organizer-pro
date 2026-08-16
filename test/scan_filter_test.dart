import 'package:file_organizer_pro/models/category.dart';
import 'package:file_organizer_pro/models/scanned_file.dart';
import 'package:file_organizer_pro/services/scan_filter.dart';
import 'package:flutter_test/flutter_test.dart';

ScannedFile _file(String name, {int size = 100, DateTime? modified}) {
  return ScannedFile(
    path: r'C:\data\' + name,
    name: name,
    extension: name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '',
    size: size,
    modified: modified ?? DateTime(2026, 1, 1),
  );
}

void main() {
  final files = [
    _file('photo.jpg', size: 2048 * 1024, modified: DateTime(2026, 7, 21)),
    _file('report.PDF', size: 450 * 1024, modified: DateTime(2026, 7, 30)),
    _file('movie.mkv', size: 300 * 1024 * 1024, modified: DateTime(2026, 4, 19)),
    _file('notes.txt', size: 12 * 1024, modified: DateTime(2026, 7, 8)),
    _file('main.dart', size: 6 * 1024, modified: DateTime(2026, 8, 11)),
    _file('archive.zip', size: 45 * 1024 * 1024, modified: DateTime(2026, 3, 12)),
  ];

  test('no filters returns all files', () {
    final result = filterAndSortFiles(files);
    expect(result.length, 6);
  });

  test('query matches name case-insensitively', () {
    final result = filterAndSortFiles(files, query: 'REPORT');
    expect(result.single.name, 'report.PDF');
  });

  test('query matches path', () {
    final result = filterAndSortFiles(files, query: r'c:\data');
    expect(result.length, 6);
  });

  test('category filter', () {
    final result = filterAndSortFiles(files, category: FileCategory.images);
    expect(result.single.name, 'photo.jpg');
  });

  test('size range filter', () {
    final result = filterAndSortFiles(
      files,
      minMb: 1,
      maxMb: 100,
    );
    expect(result.map((f) => f.name).toSet(),
        {'photo.jpg', 'archive.zip'});
  });

  test('date range filter is inclusive of the end day', () {
    final result = filterAndSortFiles(
      files,
      from: DateTime(2026, 7, 8),
      to: DateTime(2026, 7, 21),
    );
    expect(result.map((f) => f.name).toSet(),
        {'photo.jpg', 'notes.txt'});
  });

  test('sort by size ascending and descending', () {
    final asc = filterAndSortFiles(files, sortColumn: 2, sortAscending: true);
    expect(asc.first.name, 'main.dart');
    expect(asc.last.name, 'movie.mkv');

    final desc = filterAndSortFiles(files, sortColumn: 2, sortAscending: false);
    expect(desc.first.name, 'movie.mkv');
    expect(desc.last.name, 'main.dart');
  });

  test('sort by name is case-insensitive', () {
    final result = filterAndSortFiles(files, sortColumn: 0);
    expect(result.first.name, 'archive.zip');
  });

  test('combined filters and sort', () {
    final result = filterAndSortFiles(
      files,
      minMb: 1,
      sortColumn: 2,
      sortAscending: false,
    );
    expect(result.map((f) => f.name).toList(),
        ['movie.mkv', 'archive.zip', 'photo.jpg']);
  });

  test('returns a new list and does not mutate input', () {
    final before = files.length;
    filterAndSortFiles(files, query: 'zzz-none');
    expect(files.length, before);
  });
}
