/// A broad file category used for organizing files into folders.
enum FileCategory {
  images('Images', '🖼️'),
  documents('Documents', '📄'),
  videos('Videos', '🎬'),
  audio('Audio', '🎵'),
  archives('Archives', '🗜️'),
  applications('Applications', '📦'),
  code('Code', '💻'),
  other('Other', '📁');

  const FileCategory(this.label, this.icon);

  /// Folder name used when organizing files into this category.
  final String label;
  final String icon;

  static const Map<String, FileCategory> _byExtension = {
    // Images
    'jpg': images, 'jpeg': images, 'png': images, 'gif': images,
    'bmp': images, 'webp': images, 'svg': images, 'ico': images,
    'tif': images, 'tiff': images, 'heic': images, 'heif': images,
    'raw': images, 'jfif': images,
    // Documents
    'pdf': documents, 'doc': documents, 'docx': documents,
    'xls': documents, 'xlsx': documents, 'ppt': documents,
    'pptx': documents, 'txt': documents, 'md': documents,
    'rtf': documents, 'odt': documents, 'csv': documents,
    'epub': documents, 'tex': documents,
    // Videos
    'mp4': videos, 'mkv': videos, 'avi': videos, 'mov': videos,
    'wmv': videos, 'flv': videos, 'webm': videos, 'm4v': videos,
    'mpeg': videos, 'mpg': videos, '3gp': videos,
    // Audio
    'mp3': audio, 'wav': audio, 'flac': audio, 'aac': audio,
    'ogg': audio, 'm4a': audio, 'wma': audio, 'opus': audio,
    'aiff': audio,
    // Archives
    'zip': archives, 'rar': archives, '7z': archives, 'tar': archives,
    'gz': archives, 'bz2': archives, 'xz': archives, 'iso': archives,
    'cab': archives, 'tgz': archives, 'jar': archives,
    // Applications
    'exe': applications, 'msi': applications, 'apk': applications,
    'app': applications, 'deb': applications, 'rpm': applications,
    'bat': applications, 'cmd': applications,
    'dmg': applications, 'ps1': applications,
    // Code
    'py': code, 'dart': code, 'js': code, 'jsx': code, 'ts': code,
    'tsx': code, 'java': code, 'c': code, 'cpp': code, 'h': code,
    'hpp': code, 'cs': code, 'go': code, 'rs': code, 'php': code,
    'rb': code, 'swift': code, 'kt': code, 'html': code, 'css': code,
    'json': code, 'xml': code, 'yaml': code, 'yml': code, 'sql': code,
    'toml': code,
  };

  /// Returns the category for a file extension (with or without the leading dot).
  static FileCategory fromExtension(String extension) {
    final ext = extension.replaceFirst('.', '').trim().toLowerCase();
    return _byExtension[ext] ?? other;
  }
}
