import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Generates a disposable folder of sample files so users can try every
/// feature without touching their real files.
///
/// Everything lives under `<system temp>/file_organizer_pro_demo/` — the app
/// never reads or writes anywhere else in demo mode.
class DemoService {
  const DemoService();

  static const folderName = 'file_organizer_pro_demo';

  static String get demoRoot =>
      p.join(Directory.systemTemp.path, folderName);

  /// Creates (or recreates) the demo folder and returns its path.
  Future<String> createDemoFolder() async {
    final root = Directory(demoRoot);
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);

    final rng = Random(20260815);
    await _writeBytes(root, 'beach.jpg', _bytes(rng, 512 * 1024));
    await _writeBytes(root, 'beach copy.jpg', _bytes(rng, 512 * 1024));
    // A real duplicate pair — identical content, so hashing matches.
    final dup = _bytes(rng, 300 * 1024);
    await _writeBytes(root, 'wallpaper.png', dup);
    await _writeBytes(root, 'wallpaper (backup).png', dup);

    await _writeText(root, 'invoice_2026_08.pdf', _lorem(1400));
    await _writeText(root, 'invoice_2026_07.pdf', _lorem(1600));
    await _writeText(root, 'report.txt', _lorem(900));
    await _writeText(root, 'notes.md', '# Demo notes\n\nGenerated sample file.');
    await _writeBytes(root, 'vacation-clip.mp4', _bytes(rng, 2 * 1024 * 1024));
    await _writeBytes(root, 'song.mp3', _bytes(rng, 380 * 1024));
    await _writeBytes(root, 'backup.zip', _bytes(rng, 420 * 1024));
    await _writeText(root, 'main.dart',
        "void main() => print('hello');\n");
    await _writeText(root, 'script.py', 'print("hi")\n');
    await _writeText(root, 'tool.bat', '@echo off\nrem demo file\n');
    await _writeBytes(root, 'archive.dat', _bytes(rng, 250 * 1024));

    return root.path;
  }

  Future<void> _writeBytes(Directory dir, String name, List<int> bytes) =>
      File(p.join(dir.path, name)).writeAsBytes(bytes, flush: true);

  Future<void> _writeText(Directory dir, String name, String text) =>
      File(p.join(dir.path, name)).writeAsString(text, flush: true);

  List<int> _bytes(Random rng, int count) =>
      List<int>.generate(count, (_) => rng.nextInt(256));

  String _lorem(int length) {
    const words = [
      'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing',
      'elit', 'sed', 'do', 'eiusmod', 'tempor', 'incididunt', 'ut', 'labore',
    ];
    final sb = StringBuffer();
    while (sb.length < length) {
      sb.write(words[Random().nextInt(words.length)]);
      sb.write(' ');
    }
    return sb.toString();
  }
}
