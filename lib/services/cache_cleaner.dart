import 'dart:math' as math;

import '../core/database_service.dart';
import 'demo_service.dart';

/// A snapshot of everything the app stores that is regenerable cache:
/// stored scan summaries (dashboard stats), the demo sample folder, and
/// the on-disk size of the database files (including the WAL/journal).
///
/// History (undo records), custom rules and preferences are *not* cache and
/// are never touched by the cleaner.
class CacheSnapshot {
  const CacheSnapshot({
    required this.scanCount,
    required this.scanPayloadBytes,
    required this.dbBytes,
    required this.demoBytes,
  });

  /// Number of stored scan summaries.
  final int scanCount;

  /// Stored payload bytes of the `scans` table.
  final int scanPayloadBytes;

  /// On-disk bytes of the database files (`.db` + `-wal` + `-shm`).
  final int dbBytes;

  /// On-disk bytes of the demo sample folder.
  final int demoBytes;

  /// Approximate total cache footprint on disk.
  int get totalBytes => dbBytes + demoBytes;

  bool get isEmpty => totalBytes == 0;
}

/// What a [CacheCleanerService.clean] run removed.
class CacheCleanResult {
  const CacheCleanResult({
    required this.scanSummariesCleared,
    required this.demoFolderRemoved,
    required this.bytesFreed,
  });

  final int scanSummariesCleared;
  final bool demoFolderRemoved;

  /// Approximate bytes reclaimed on disk (clamped at zero).
  final int bytesFreed;

  bool get freedNothing => bytesFreed <= 0;
}

/// Clamps a before/after delta so a slightly-larger after (e.g. WAL churn)
/// never reports a negative "freed" amount.
int computeFreedBytes(int beforeTotal, int afterTotal) =>
    math.max(0, beforeTotal - afterTotal);

/// Clears every piece of regenerable cache the app produces: stored scan
/// summaries, the disposable demo sample folder, and stale SQLite journal
/// overhead (checkpoint + VACUUM reclaims it).
///
/// Operation history, custom rules, preferences and — above all — the
/// user's real files are never touched.
class CacheCleanerService {
  const CacheCleanerService({DatabaseService? database})
      : _database = database;

  final DatabaseService? _database;

  DatabaseService get _db => _database ?? DatabaseService.instance;

  /// Current regenerable cache footprint.
  Future<CacheSnapshot> snapshot() async {
    final stats = await _db.scanCacheStats();
    final breakdown = await _db.storageBreakdown();
    return CacheSnapshot(
      scanCount: stats.scanCount,
      scanPayloadBytes: breakdown.cacheBytes,
      dbBytes: stats.dbBytes,
      demoBytes: await DemoService.demoFolderBytes(),
    );
  }

  /// Clears all regenerable cache and reports what was freed.
  Future<CacheCleanResult> clean() async {
    final before = await snapshot();
    await _db.clearScanCache();
    var demoRemoved = false;
    try {
      demoRemoved = await DemoService.deleteFolder(DemoService.demoRoot);
    } catch (_) {
      // A locked temp file is not worth failing the whole clear over.
    }
    final after = await snapshot();
    return CacheCleanResult(
      scanSummariesCleared: before.scanCount,
      demoFolderRemoved: demoRemoved,
      bytesFreed: computeFreedBytes(before.totalBytes, after.totalBytes),
    );
  }
}
