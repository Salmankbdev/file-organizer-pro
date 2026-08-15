import 'dart:io';

import 'package:path/path.dart' as p;

/// Formatting helpers shared across the UI.
class FileUtils {
  FileUtils._();

  /// Formats a byte count as a human-readable string, e.g. `1.4 GB`.
  static String humanSize(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
    double value = bytes.toDouble();
    var unit = -1;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }

  /// Formats a duration as a short human string, e.g. `2.4 s`.
  static String humanDuration(Duration d) {
    if (d.inSeconds < 1) return '${d.inMilliseconds} ms';
    if (d.inMinutes < 1) return '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
    if (d.inHours < 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  /// Formats a date/time compactly, e.g. `Aug 15, 14:32`.
  static String humanDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// The default Windows Downloads folder, or null if it can't be resolved.
  static String? defaultDownloadsPath() {
    final profile = Platform.environment['USERPROFILE'];
    if (profile == null || profile.isEmpty) return null;
    final candidate = p.join(profile, 'Downloads');
    return Directory(candidate).existsSync() ? candidate : null;
  }
}

/// Opens files and folders using the OS shell.
class Shell {
  Shell._();

  /// Opens [path] with its default application.
  static Future<void> open(String path) async {
    await Process.run('cmd', ['/c', 'start', '', path]);
  }

  /// Reveals [path] in Windows Explorer.
  static Future<void> showInFolder(String path) async {
    await Process.run('explorer', ['/select,$path']);
  }
}
