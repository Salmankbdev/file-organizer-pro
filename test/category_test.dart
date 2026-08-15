import 'package:file_organizer_pro/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileCategory.fromExtension', () {
    test('maps common extensions to their category', () {
      expect(FileCategory.fromExtension('jpg'), FileCategory.images);
      expect(FileCategory.fromExtension('PNG'), FileCategory.images);
      expect(FileCategory.fromExtension('.webp'), FileCategory.images);
      expect(FileCategory.fromExtension('pdf'), FileCategory.documents);
      expect(FileCategory.fromExtension('docx'), FileCategory.documents);
      expect(FileCategory.fromExtension('mp4'), FileCategory.videos);
      expect(FileCategory.fromExtension('mkv'), FileCategory.videos);
      expect(FileCategory.fromExtension('mp3'), FileCategory.audio);
      expect(FileCategory.fromExtension('wav'), FileCategory.audio);
      expect(FileCategory.fromExtension('zip'), FileCategory.archives);
      expect(FileCategory.fromExtension('rar'), FileCategory.archives);
      expect(FileCategory.fromExtension('exe'), FileCategory.applications);
      expect(FileCategory.fromExtension('msi'), FileCategory.applications);
      expect(FileCategory.fromExtension('py'), FileCategory.code);
      expect(FileCategory.fromExtension('dart'), FileCategory.code);
      expect(FileCategory.fromExtension('js'), FileCategory.code);
      expect(FileCategory.fromExtension('ts'), FileCategory.code);
    });

    test('is case-insensitive and tolerates a leading dot', () {
      expect(FileCategory.fromExtension('.PDF'), FileCategory.documents);
      expect(FileCategory.fromExtension('  JpEg '), FileCategory.images);
    });

    test('falls back to other for unknown extensions and no extension', () {
      expect(FileCategory.fromExtension('xyzabc'), FileCategory.other);
      expect(FileCategory.fromExtension(''), FileCategory.other);
    });
  });
}
