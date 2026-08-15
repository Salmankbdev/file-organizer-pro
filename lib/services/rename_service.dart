import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/move_operation.dart';
import '../models/scanned_file.dart';

/// The pattern applied to derive new file names.
enum RenameMode {
  findReplace,
  prefix,
  suffix,
  numbering,
  case_;

  String get label => switch (this) {
        RenameMode.findReplace => 'Find & replace',
        RenameMode.prefix => 'Add prefix',
        RenameMode.suffix => 'Add suffix',
        RenameMode.numbering => 'Number files',
        RenameMode.case_ => 'Change case',
      };
}

/// Case transformation for [RenameMode.case_].
enum CaseMode {
  lower('Lowercase', 'hello.txt'),
  upper('UPPERCASE', 'HELLO.TXT'),
  title('Title Case', 'Hello World');

  const CaseMode(this.label, this.example);
  final String label;
  final String example;
}

/// Options describing how new names are derived.
class RenameOptions {
  const RenameOptions({
    this.mode = RenameMode.findReplace,
    this.find = '',
    this.replace = '',
    this.caseSensitive = false,
    this.replaceAll = true,
    this.prefix = '',
    this.suffix = '',
    this.startAt = 1,
    this.padding = 3,
    this.caseMode = CaseMode.lower,
  });

  final RenameMode mode;
  final String find;
  final String replace;
  final bool caseSensitive;
  final bool replaceAll;
  final String prefix;
  final String suffix;
  final int startAt;
  final int padding;
  final CaseMode caseMode;

  RenameOptions copyWith({
    RenameMode? mode,
    String? find,
    String? replace,
    bool? caseSensitive,
    bool? replaceAll,
    String? prefix,
    String? suffix,
    int? startAt,
    int? padding,
    CaseMode? caseMode,
  }) =>
      RenameOptions(
        mode: mode ?? this.mode,
        find: find ?? this.find,
        replace: replace ?? this.replace,
        caseSensitive: caseSensitive ?? this.caseSensitive,
        replaceAll: replaceAll ?? this.replaceAll,
        prefix: prefix ?? this.prefix,
        suffix: suffix ?? this.suffix,
        startAt: startAt ?? this.startAt,
        padding: padding ?? this.padding,
        caseMode: caseMode ?? this.caseMode,
      );

  /// Whether the current mode has meaningful input configured.
  bool get isValid => switch (mode) {
        RenameMode.findReplace => find.isNotEmpty,
        RenameMode.prefix => prefix.isNotEmpty,
        RenameMode.suffix => suffix.isNotEmpty,
        RenameMode.numbering => true,
        RenameMode.case_ => true,
      };
}

/// A single planned rename.
class PlannedRename {
  const PlannedRename({
    required this.file,
    required this.newPath,
  });

  final ScannedFile file;

  /// Absolute path the file will be renamed to (before conflict resolution).
  final String newPath;

  String get newName => p.basename(newPath);
}

/// A prepared (but not yet applied) batch of renames.
class RenamePlan {
  const RenamePlan({required this.rootPath, required this.renames});

  final String rootPath;
  final List<PlannedRename> renames;

  /// Planned renames whose target name is already taken (by another planned
  /// rename or by an existing file). Advisory — apply still resolves them
  /// safely with ` (n)` suffixes.
  Set<PlannedRename> conflicts(Iterable<String> existingNames) {
    final seen = <String>{};
    final conflicts = <PlannedRename>{};
    for (final rename in renames) {
      final name = rename.newName.toLowerCase();
      if (seen.contains(name) || existingNames.contains(name)) {
        conflicts.add(rename);
      }
      seen.add(name);
    }
    return conflicts;
  }
}

/// The outcome of applying a rename plan.
class RenameResult {
  const RenameResult({
    required this.renamed,
    required this.skipped,
    required this.failed,
    required this.appliedPaths,
  });

  final int renamed;
  final int skipped;
  final int failed;

  /// Original path -> path actually used after conflict resolution.
  final Map<String, String> appliedPaths;
}

/// Builds and executes batch rename plans. Renames never overwrite existing
/// files: colliding targets automatically become `name (1).ext`, and every
/// applied rename can be undone (a rename is just a move within the folder).
class RenameService {
  const RenameService();

  /// Derives new names for [files] using [options]. Files whose name would
  /// not change are omitted from the plan.
  RenamePlan buildPlan(List<ScannedFile> files, RenameOptions options) {
    final renames = <PlannedRename>[];
    var counter = options.startAt;
    for (final file in files) {
      final newName = _deriveName(file, options, counter);
      if (newName == file.name) continue; // No change — skip.
      if (options.mode == RenameMode.numbering) counter++;
      renames.add(PlannedRename(
        file: file,
        newPath: p.join(p.dirname(file.path), newName),
      ));
    }
    final rootPath =
        files.isEmpty ? '' : p.dirname(files.first.path);
    return RenamePlan(rootPath: rootPath, renames: renames);
  }

  String _deriveName(ScannedFile file, RenameOptions options, int counter) {
    final base = p.basenameWithoutExtension(file.name);
    final ext = p.extension(file.name);
    switch (options.mode) {
      case RenameMode.findReplace:
        var name = file.name;
        if (options.caseSensitive) {
          name = options.replaceAll
              ? name.replaceAll(options.find, options.replace)
              : name.replaceFirst(options.find, options.replace);
        } else {
          final re = RegExp(
            RegExp.escape(options.find),
            caseSensitive: false,
          );
          name = options.replaceAll
              ? name.replaceAll(re, options.replace)
              : name.replaceFirst(re, options.replace);
        }
        return name;

      case RenameMode.prefix:
        return '${options.prefix}${file.name}';

      case RenameMode.suffix:
        return '$base${options.suffix}$ext';

      case RenameMode.numbering:
        final number =
            counter.toString().padLeft(options.padding.clamp(0, 12), '0');
        return '${options.prefix}$number${options.suffix}$ext';

      case RenameMode.case_:
        return switch (options.caseMode) {
          CaseMode.lower => '${base.toLowerCase()}${ext.toLowerCase()}',
          CaseMode.upper => '${base.toUpperCase()}${ext.toUpperCase()}',
          CaseMode.title => '${_titleCase(base)}${ext.toLowerCase()}',
        };
    }
  }

  static String _titleCase(String input) {
    final buffer = StringBuffer();
    var capitalize = true;
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final isWordChar = RegExp(r'[a-zA-Z0-9]').hasMatch(ch);
      if (capitalize && isWordChar) {
        buffer.write(ch.toUpperCase());
      } else {
        buffer.write(ch.toLowerCase());
      }
      capitalize = !isWordChar;
    }
    return buffer.toString();
  }

  /// Applies [plan] by renaming files in place. Targets that collide with an
  /// existing file (or an earlier rename in this batch) are given a ` (n)`
  /// suffix — nothing is ever overwritten. Continues past failures and
  /// reports them.
  Future<RenameResult> apply(
    RenamePlan plan, {
    void Function(int done, int total, String current)? onProgress,
  }) async {
    final usedTargets = <String>{};
    final total = plan.renames.length;
    var renamed = 0, skipped = 0, failed = 0;
    final appliedPaths = <String, String>{};

    for (var i = 0; i < total; i++) {
      final rename = plan.renames[i];
      final source = File(rename.file.path);
      try {
        if (!await source.exists()) {
          skipped++;
          onProgress?.call(i + 1, total, rename.file.name);
          continue;
        }
        var target = await _uniqueTarget(
            rename.newPath, usedTargets);
        await source.rename(target);
        usedTargets.add(_norm(target));
        appliedPaths[rename.file.path] = target;
        renamed++;
      } catch (_) {
        failed++;
      }
      onProgress?.call(i + 1, total, rename.file.name);
    }

    return RenameResult(
      renamed: renamed,
      skipped: skipped,
      failed: failed,
      appliedPaths: appliedPaths,
    );
  }

  /// Picks a non-colliding sibling path by appending ` (n)` before the
  /// extension, checking both the filesystem and paths already used by this
  /// batch.
  Future<String> _uniqueTarget(String candidate, Set<String> used) async {
    if (!await File(candidate).exists() && !used.contains(_norm(candidate))) {
      return candidate;
    }
    final dir = p.dirname(candidate);
    final base = p.basenameWithoutExtension(candidate);
    final ext = p.extension(candidate);
    var n = 1;
    while (true) {
      final next = p.join(dir, '$base ($n)$ext');
      if (!await File(next).exists() && !used.contains(_norm(next))) {
        return next;
      }
      n++;
    }
  }

  static String _norm(String path) =>
      path.replaceAll('\\', '/').toLowerCase();

  /// Builds the persisted operation records for an applied plan.
  List<MoveOperation> buildOperations({
    required int batchId,
    required RenamePlan plan,
    required Map<String, String> appliedPaths,
  }) {
    final now = DateTime.now();
    return [
      for (final rename in plan.renames)
        if (appliedPaths.containsKey(rename.file.path))
          MoveOperation(
            batchId: batchId,
            fileName: rename.file.name,
            fromPath: rename.file.path,
            toPath: appliedPaths[rename.file.path]!,
            action: 'rename',
            status: 'completed',
            createdAt: now,
          ),
    ];
  }
}
