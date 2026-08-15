import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/category.dart';
import '../models/custom_rule.dart';
import '../models/move_operation.dart';
import '../models/scanned_file.dart';
import '../models/scan_result.dart';
import 'scanner_service.dart';

/// A single planned move.
class PlannedMove {
  const PlannedMove({
    required this.file,
    required this.targetPath,
  });

  final ScannedFile file;
  final String targetPath;
}

/// A prepared (but not yet applied) reorganization of a folder.
class OrganizePlan {
  const OrganizePlan({
    required this.rootPath,
    required this.moves,
  });

  final String rootPath;
  final List<PlannedMove> moves;

  Map<FileCategory, List<PlannedMove>> get byCategory {
    final map = <FileCategory, List<PlannedMove>>{
      for (final c in FileCategory.values) c: <PlannedMove>[],
    };
    for (final m in moves) {
      map[m.file.category]!.add(m);
    }
    return map;
  }
}

/// The outcome of applying a plan.
class ApplyResult {
  const ApplyResult({
    required this.moved,
    required this.skipped,
    required this.failed,
    required this.appliedPaths,
  });

  final int moved;
  final int skipped;
  final int failed;

  /// Original path -> path actually used after conflict resolution.
  final Map<String, String> appliedPaths;
}

/// Builds and executes file organization plans.
class OrganizerService {
  const OrganizerService();

  static const _conflictSuffixStart = 1;

  /// Computes the moves needed to organize [scan]'s folder: each file with
  /// a known category is moved into `<root>/<Category>/`, unless a matching
  /// [rules] entry sends it to a custom folder instead (e.g.
  /// `Documents/Invoices`, or an absolute path like `D:/Invoices`). Rules are
  /// evaluated in order; the first enabled match wins. A rule with
  /// [CustomRule.createFolder] false only takes effect if its target folder
  /// already exists — otherwise the file falls through to the default
  /// category mapping.
  OrganizePlan buildPlan(ScanResult scan,
      {List<CustomRule> rules = const []}) {
    final moves = <PlannedMove>[];
    for (final file in scan.files) {
      final rule = _firstMatchingRule(file, rules);
      if (rule != null) {
        final targetDir = ruleTargetDir(scan.folderPath, rule);
        if (rule.createFolder || _dirExists(targetDir)) {
          if (!_alreadyIn(file, targetDir)) {
            moves.add(PlannedMove(
              file: file,
              targetPath: p.join(targetDir, file.name),
            ));
          }
          continue;
        }
        // Folder missing and rule says don't create it — fall through.
      }
      if (file.category == FileCategory.other) continue;
      final categoryDir = p.join(scan.folderPath, file.category.label);
      if (!file.needsOrganizing(categoryDir: categoryDir)) continue;
      moves.add(PlannedMove(
        file: file,
        targetPath: p.join(categoryDir, file.name),
      ));
    }
    return OrganizePlan(rootPath: scan.folderPath, moves: moves);
  }

  /// Resolves a rule's target to an absolute directory: relative targets are
  /// joined to the scan root, absolute targets (drive letter, UNC, or leading
  /// `/` or `\`) are used as-is.
  static String ruleTargetDir(String scanRoot, CustomRule rule) {
    final target = rule.targetFolder.trim();
    if (target.contains(':') ||
        target.startsWith('/') ||
        target.startsWith(r'\')) {
      return target;
    }
    return p.join(scanRoot, target);
  }

  /// True when [path] points into a protected system folder.
  static bool isProtectedTarget(String path) =>
      ScannerService.isProtected(path);

  static bool _dirExists(String path) => Directory(path).existsSync();

  CustomRule? _firstMatchingRule(
      ScannedFile file, List<CustomRule> rules) {
    for (final rule in rules) {
      if (rule.enabled && rule.matches(file)) return rule;
    }
    return null;
  }

  bool _alreadyIn(ScannedFile file, String targetDir) {
    final parent = _norm(File(file.path).parent.path);
    final target = _norm(targetDir);
    return parent == target || parent.startsWith('$target/');
  }

  /// Lower-cases and normalizes separators so comparisons work regardless of
  /// whether paths use `/` or `\`.
  static String _norm(String path) =>
      path.replaceAll('\\', '/').toLowerCase();

  /// Applies [plan], creating category folders and moving files.
  /// Conflicts are resolved by appending ` (1)`, ` (2)`, ... unless
  /// [preventOverwrite] is false, in which case conflicting files are
  /// skipped. Returns per-outcome counts.
  Future<ApplyResult> apply(
    OrganizePlan plan, {
    required bool preventOverwrite,
    void Function(int done, int total, String current)? onProgress,
  }) async {
    final createdDirs = <String>{};
    final total = plan.moves.length;
    var moved = 0, skipped = 0, failed = 0;
    final appliedPaths = <String, String>{};

    for (var i = 0; i < total; i++) {
      final move = plan.moves[i];
      final source = File(move.file.path);
      final categoryDir = p.dirname(move.targetPath);
      try {
        if (createdDirs.add(categoryDir)) {
          await Directory(categoryDir).create(recursive: true);
        }

        var targetPath = move.targetPath;
        if (await File(targetPath).exists()) {
          if (!preventOverwrite) {
            skipped++;
            onProgress?.call(i + 1, total, move.file.name);
            continue;
          }
          targetPath = await _uniquePath(targetPath);
        }

        await source.rename(targetPath);
        appliedPaths[move.file.path] = targetPath;
        moved++;
      } catch (_) {
        failed++;
      }
      onProgress?.call(i + 1, total, move.file.name);
    }

    return ApplyResult(
      moved: moved,
      skipped: skipped,
      failed: failed,
      appliedPaths: appliedPaths,
    );
  }

  /// Picks a non-colliding sibling path by appending ` (n)` before the
  /// extension, e.g. `report (1).pdf`.
  Future<String> _uniquePath(String candidate) async {
    final dir = p.dirname(candidate);
    final base = p.basenameWithoutExtension(candidate);
    final ext = p.extension(candidate);
    var n = _conflictSuffixStart;
    while (true) {
      final next = p.join(dir, '$base ($n)$ext');
      if (!await File(next).exists()) return next;
      n++;
    }
  }

  /// Builds the persisted operation records for an applied plan.
  List<MoveOperation> buildOperations({
    required int batchId,
    required List<PlannedMove> moves,
    required Map<String, String> appliedPaths,
  }) {
    final now = DateTime.now();
    return [
      for (final move in moves)
        if (appliedPaths.containsKey(move.file.path))
          MoveOperation(
            batchId: batchId,
            fileName: move.file.name,
            fromPath: move.file.path,
            toPath: appliedPaths[move.file.path]!,
            action: 'organize',
            status: 'completed',
            createdAt: now,
          ),
    ];
  }

  /// Builds persisted `undo` records for a reverted batch.
  List<MoveOperation> buildUndoOperations({
    required List<MoveOperation> batch,
    required Set<String> undonePaths,
  }) {
    final now = DateTime.now();
    return [
      for (final op in batch.reversed)
        if (undonePaths.contains(op.fromPath))
          MoveOperation(
            batchId: op.batchId,
            fileName: op.fileName,
            fromPath: op.fromPath,
            toPath: op.toPath,
            action: 'undo',
            status: 'completed',
            createdAt: now,
          ),
    ];
  }

  /// Reverses a batch of organize operations, moving files back to their
  /// original locations. Returns the set of original paths restored.
  Future<({int undone, int failed, Set<String> restored})> undo(
      List<MoveOperation> batch) async {
    var undone = 0, failed = 0;
    final restored = <String>{};
    for (final op in batch.reversed) {
      try {
        final source = File(op.toPath);
        if (!await source.exists()) {
          failed++;
          continue;
        }
        // If something now occupies the original location, pick a unique name
        // rather than overwriting it.
        var from = op.fromPath;
        if (await File(from).exists()) {
          from = await _uniquePath(from);
        }
        await source.rename(from);
        restored.add(op.fromPath);
        undone++;
      } catch (_) {
        failed++;
      }
    }
    return (undone: undone, failed: failed, restored: restored);
  }
}
