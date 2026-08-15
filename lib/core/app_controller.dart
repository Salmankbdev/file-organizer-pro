import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../models/custom_rule.dart';
import '../models/duplicate_group.dart';
import '../models/move_operation.dart';
import '../models/scanned_file.dart';
import '../models/scan_result.dart';
import '../services/archive_service.dart';
import '../services/demo_service.dart';
import '../services/duplicate_service.dart';
import '../services/organizer_service.dart';
import '../services/scanner_service.dart';
import '../services/settings_service.dart';
import 'database_service.dart';

enum ScanPhase { idle, scanning, done, error }

enum OrganizePhase { idle, applying, done }

enum FindPhase { idle, running, done }

/// Central application state. Exposed to the widget tree via [AppScope].
class AppController extends ChangeNotifier {
  AppController({
    required this.settings,
    DatabaseService? database,
    ScannerService? scanner,
    OrganizerService? organizer,
    DuplicateService? duplicateFinder,
    DemoService? demo,
    ArchiveService? archiveService,
  })  : database = database ?? DatabaseService.instance,
        scanner = scanner ?? const ScannerService(),
        organizer = organizer ?? const OrganizerService(),
        duplicateFinder = duplicateFinder ?? const DuplicateService(),
        demo = demo ?? const DemoService(),
        archiveService = archiveService ?? const ArchiveService();

  final SettingsService settings;
  final DatabaseService database;
  final ScannerService scanner;
  final OrganizerService organizer;
  final DuplicateService duplicateFinder;
  final DemoService demo;
  final ArchiveService archiveService;

  // --- Scan state ---
  ScanPhase scanPhase = ScanPhase.idle;
  ScanResult? currentScan;
  String? scanError;
  int scanProgressFiles = 0;
  int scanProgressBytes = 0;
  bool _scanning = false;

  // --- Organize state ---
  OrganizePhase organizePhase = OrganizePhase.idle;
  OrganizePlan? currentPlan;
  ApplyResult? lastApply;
  int organizeProgress = 0;
  int organizeTotal = 0;
  String organizeCurrentFile = '';
  String? organizeMessage;
  bool _organizing = false;

  // --- Duplicate finder state ---
  FindPhase duplicatePhase = FindPhase.idle;
  List<DuplicateGroup>? duplicateGroups;
  int duplicateProgress = 0;
  int duplicateTotal = 0;
  bool _findingDuplicates = false;

  // --- Large-file finder state ---
  FindPhase largePhase = FindPhase.idle;
  List<ScannedFile>? largeFiles;
  int largeThresholdBytes = 0;
  bool _findingLarge = false;

  // --- Archive extraction state ---
  FindPhase extractPhase = FindPhase.idle;
  List<ExtractPlanEntry> extractPlan = [];
  ExtractResult? extractResult;
  int extractProgress = 0;
  int extractTotal = 0;
  String extractCurrent = '';
  bool _extracting = false;

  // --- Rules state ---
  List<CustomRule> rules = [];

  // --- History state ---
  List<MoveOperation> history = [];
  int organizedFileCount = 0;
  Map<String, Object?>? latestScanRow;

  Future<void> init() async {
    await settings.init();
    await database.init();
    await refreshHistory();
    rules = await database.rules();
  }

  // --- Scans -------------------------------------------------------------

  Future<void> scanFolder(String path) async {
    if (_scanning) return;
    _scanning = true;
    scanPhase = ScanPhase.scanning;
    scanError = null;
    scanProgressFiles = 0;
    scanProgressBytes = 0;
    currentScan = null;
    // Finder results refer to the previous scan; drop them.
    duplicateGroups = null;
    duplicatePhase = FindPhase.idle;
    largeFiles = null;
    largePhase = FindPhase.idle;
    extractPlan = [];
    extractPhase = FindPhase.idle;
    extractResult = null;
    notifyListeners();

    try {
      final result = await scanner.scan(
        path,
        onProgress: (files, bytes) {
          scanProgressFiles = files;
          scanProgressBytes = bytes;
          notifyListeners();
        },
      );
      currentScan = result;
      scanPhase = ScanPhase.done;
      await database.insertScan(result);
      latestScanRow = await database.latestScanRow();
      notifyListeners();
    } catch (e) {
      scanError = e.toString();
      scanPhase = ScanPhase.error;
      notifyListeners();
    } finally {
      _scanning = false;
    }
  }

  /// Loads a generated sample folder (in the OS temp directory) and scans it.
  /// Never touches the user's real files.
  Future<void> loadDemoData() async {
    final path = await demo.createDemoFolder();
    await scanFolder(path);
  }

  bool get canOrganize =>
      currentScan != null && currentScan!.folderPath.isNotEmpty;

  /// Plans the reorganization of the current scan, if allowed. Rules whose
  /// absolute target points into a protected system folder are dropped when
  /// system-folder protection is enabled.
  String? preparePlan() {
    final scan = currentScan;
    if (scan == null) return 'Run a scan first.';
    if (settings.protectSystemFolders &&
        ScannerService.isProtected(scan.folderPath)) {
      return 'This folder is protected. Enable "System-folder protection" '
          'in Settings to allow organizing it.';
    }
    currentPlan = organizer.buildPlan(scan, rules: _safeRules());
    organizePhase = OrganizePhase.idle;
    lastApply = null;
    organizeMessage = null;
    notifyListeners();
    return null;
  }

  /// Rules with [CustomRule.createFolder] targets, minus any rule whose
  /// absolute target is a protected system folder (when protection is on).
  List<CustomRule> _safeRules() {
    if (!settings.protectSystemFolders) return rules;
    return [
      for (final rule in rules)
        if (!OrganizerService.isProtectedTarget(
            OrganizerService.ruleTargetDir('', rule)))
          rule,
    ];
  }

  Future<void> applyPlan() async {
    final plan = currentPlan;
    if (plan == null || _organizing) return;
    _organizing = true;
    organizePhase = OrganizePhase.applying;
    organizeProgress = 0;
    organizeTotal = plan.moves.length;
    organizeMessage = null;
    notifyListeners();

    try {
      final result = await organizer.apply(
        plan,
        preventOverwrite: settings.preventOverwrite,
        onProgress: (done, total, current) {
          organizeProgress = done;
          organizeTotal = total;
          organizeCurrentFile = current;
          notifyListeners();
        },
      );
      lastApply = result;
      final batchId = await database.nextBatchId();
      final ops = organizer.buildOperations(
        batchId: batchId,
        moves: plan.moves,
        appliedPaths: result.appliedPaths,
      );
      await database.insertOperations(ops);
      organizePhase = OrganizePhase.done;
      organizeMessage =
          'Moved ${result.moved} file(s)'
          '${result.skipped > 0 ? ', skipped ${result.skipped}' : ''}'
          '${result.failed > 0 ? ', failed ${result.failed}' : ''}.';
      await refreshHistory();
    } catch (e) {
      organizePhase = OrganizePhase.idle;
      organizeMessage = 'Apply failed: $e';
    } finally {
      _organizing = false;
      notifyListeners();
    }
  }

  Future<String?> undoLast() async {
    final batch = await database.latestBatchOperations();
    if (batch.isEmpty) return 'Nothing to undo.';
    final latest = batch.firstWhere(
      (op) => op.status == 'completed',
      orElse: () => batch.first,
    );
    if (latest.action == 'extract') {
      return _undoExtraction(batch);
    }

    final organizes =
        batch.where((op) => op.action == 'organize').toList();
    if (organizes.isEmpty) return 'Nothing to undo.';

    final result = await organizer.undo(organizes);
    final undoOps = organizer.buildUndoOperations(
      batch: organizes,
      undonePaths: result.restored,
    );
    if (undoOps.isNotEmpty) {
      await database.insertOperations(undoOps);
    }
    await refreshHistory();
    return result.undone == organizes.length
        ? 'Undid ${result.undone} file move(s).'
        : 'Undid ${result.undone} of ${organizes.length} file move(s) '
            '(${result.failed} could not be restored).';
  }

  /// Reverses an extraction batch: removes the files the archive wrote and
  /// any of its folders that are now empty, then records the undo.
  Future<String?> _undoExtraction(List<MoveOperation> batch) async {
    final extractOps =
        batch.where((op) => op.action == 'extract').toList();
    if (extractOps.isEmpty) return 'Nothing to undo.';

    var removedFiles = 0;
    final undoOps = <MoveOperation>[];
    for (final op in extractOps) {
      final createdFiles = <String>[];
      final createdDirs = <String>[];
      if (op.details != null) {
        try {
          final decoded = jsonDecode(op.details!)
              as Map<String, dynamic>;
          createdFiles.addAll(
              ((decoded['files'] as List?) ?? []).cast<String>());
          createdDirs.addAll(
              ((decoded['dirs'] as List?) ?? []).cast<String>());
        } catch (_) {
          // Corrupt details — nothing we can safely remove.
        }
      }
      removedFiles += await ArchiveService.undoCleanup(
          createdFiles, createdDirs);
      undoOps.add(MoveOperation(
        batchId: op.batchId,
        fileName: op.fileName,
        fromPath: op.fromPath,
        toPath: op.toPath,
        action: 'extract_undo',
        status: 'completed',
        createdAt: DateTime.now(),
      ));
    }
    await database.insertOperations(undoOps);
    await refreshHistory();
    return 'Removed $removedFiles extracted file(s) and cleaned up empty '
        'folders.';
  }

  // --- Duplicate finder --------------------------------------------------

  Future<void> findDuplicates() async {
    final scan = currentScan;
    if (scan == null || _findingDuplicates) return;
    _findingDuplicates = true;
    duplicatePhase = FindPhase.running;
    duplicateProgress = 0;
    duplicateTotal = 0;
    duplicateGroups = null;
    notifyListeners();

    try {
      duplicateGroups = await duplicateFinder.find(
        scan,
        onProgress: (done, total) {
          duplicateProgress = done;
          duplicateTotal = total;
          notifyListeners();
        },
      );
      duplicatePhase = FindPhase.done;
    } catch (e) {
      duplicatePhase = FindPhase.idle;
      duplicateGroups = null;
    } finally {
      _findingDuplicates = false;
      notifyListeners();
    }
  }

  /// Number of files that have at least one identical copy (from the last
  /// duplicate run), or null if duplicates haven't been searched.
  int? get duplicateFileCount {
    final groups = duplicateGroups;
    if (groups == null) return null;
    return groups.fold<int>(0, (sum, g) => sum + g.files.length);
  }

  int? get duplicateWastedBytes {
    final groups = duplicateGroups;
    if (groups == null) return null;
    return groups.fold<int>(0, (sum, g) => sum + g.wastedBytes);
  }

  /// Permanently deletes the given files (after the UI confirms).
  /// Returns the number deleted; files that couldn't be removed are skipped.
  Future<int> deleteFiles(List<String> paths) async {
    var deleted = 0;
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          deleted++;
        }
      } catch (_) {
        // Continue with the remaining files.
      }
    }
    return deleted;
  }

  // --- Large-file finder -------------------------------------------------

  Future<void> findLargeFiles(int minBytes) async {
    final scan = currentScan;
    if (scan == null || _findingLarge) return;
    _findingLarge = true;
    largePhase = FindPhase.running;
    largeThresholdBytes = minBytes;
    largeFiles = null;
    notifyListeners();

    // Simulate a brief pass; filtering is cheap but gives the UI a beat.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final found = scan.files.where((f) => f.size >= minBytes).toList()
      ..sort((a, b) => b.size.compareTo(a.size));
    largeFiles = found;
    largePhase = FindPhase.done;
    _findingLarge = false;
    notifyListeners();
  }

  // --- Archive extraction ------------------------------------------------

  /// Builds (but does not run) the extraction plan for the current scan.
  String? prepareExtract() {
    final scan = currentScan;
    if (scan == null) return 'Run a scan first.';
    if (settings.protectSystemFolders &&
        ScannerService.isProtected(scan.folderPath)) {
      return 'This folder is protected. Enable "System-folder protection" '
          'in Settings to allow extracting archives.';
    }
    extractPlan = archiveService.buildPlan(scan);
    extractPhase = FindPhase.idle;
    extractResult = null;
    notifyListeners();
    return null;
  }

  Future<void> applyExtract() async {
    final plan = extractPlan;
    if (plan.isEmpty || _extracting) return;
    _extracting = true;
    extractPhase = FindPhase.running;
    extractProgress = 0;
    extractTotal = plan.length;
    extractCurrent = '';
    extractResult = null;
    notifyListeners();

    try {
      final result = await archiveService.extract(
        plan,
        onProgress: (done, total, current) {
          extractProgress = done;
          extractTotal = total;
          extractCurrent = current;
          notifyListeners();
        },
      );
      final batchId = await database.nextBatchId();
      final ops = [
        for (final entry in plan)
          MoveOperation(
            batchId: batchId,
            fileName: entry.file.name,
            fromPath: entry.file.path,
            toPath: entry.targetDir,
            action: 'extract',
            status: 'completed',
            createdAt: DateTime.now(),
            details: jsonEncode({
              'files': result.createdFiles[entry.file.path] ?? [],
              'dirs': result.createdDirs,
            }),
          ),
      ];
      await database.insertOperations(ops);
      extractResult = result;
      extractPhase = FindPhase.done;
    } catch (e) {
      extractPhase = FindPhase.idle;
    } finally {
      _extracting = false;
      notifyListeners();
    }
  }

  // --- Rules -------------------------------------------------------------

  Future<void> refreshRules() async {
    rules = await database.rules();
    notifyListeners();
  }

  Future<void> saveRule(CustomRule rule) async {
    if (rule.id == null) {
      await database.insertRule(rule);
    } else {
      await database.updateRule(rule);
    }
    await refreshRules();
  }

  Future<void> deleteRule(int id) async {
    await database.deleteRule(id);
    await refreshRules();
  }

  Future<void> toggleRule(CustomRule rule, bool enabled) async {
    await database.updateRule(rule.copyWith(enabled: enabled));
    await refreshRules();
  }

  // --- History -----------------------------------------------------------

  Future<void> refreshHistory() async {
    history = await database.operations();
    organizedFileCount = await database.organizedFileCount();
    latestScanRow = await database.latestScanRow();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await database.clearHistory();
    await refreshHistory();
  }

  /// Wipes preferences and the database, returning the app to first-run state.
  Future<void> resetAll() async {
    await settings.resetAll();
    await database.close();
    await database.init();
    await refreshHistory();
    rules = await database.rules();
  }

  Map<String, int>? latestCategoryCounts() {
    final row = latestScanRow;
    if (row == null || row['category_counts'] == null) return null;
    try {
      final decoded = jsonDecode(row['category_counts'] as String);
      return (decoded as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return null;
    }
  }

  String get latestScanFolderLabel {
    final row = latestScanRow;
    if (row == null) return 'No scans yet';
    final folder = row['folder_path'] as String;
    return p.basename(folder);
  }
}

/// Provides [AppController] to the widget tree and rebuilds dependents on
/// change.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
