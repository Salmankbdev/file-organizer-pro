import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/custom_rule.dart';
import '../models/move_operation.dart';
import '../models/scan_result.dart';

/// Owns the SQLite database: persisted scan summaries and move history.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'file_organizer.db');
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await _createScansTable(db);
          await _createOperationsTable(db);
          await _createRulesTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createRulesTable(db);
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE rules '
                'ADD COLUMN create_folder INTEGER NOT NULL DEFAULT 1');
            await db.execute('ALTER TABLE operations '
                'ADD COLUMN details TEXT');
          }
        },
      ),
    );
    _initialized = true;
  }

  static Future<void> _createScansTable(Database db) async {
    await db.execute('''
      CREATE TABLE scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_path TEXT NOT NULL,
        file_count INTEGER NOT NULL,
        total_size INTEGER NOT NULL,
        category_counts TEXT NOT NULL,
        scanned_at TEXT NOT NULL,
        duration_ms INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createOperationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        from_path TEXT NOT NULL,
        to_path TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        details TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_operations_batch ON operations(batch_id)');
  }

  static Future<void> _createRulesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        field TEXT NOT NULL,
        condition TEXT NOT NULL,
        value TEXT NOT NULL,
        target_folder TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        create_folder INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('DatabaseService.init() must be called first');
    }
    return database;
  }

  // --- Scans -------------------------------------------------------------

  Future<int> insertScan(ScanResult scan) async {
    return db.insert('scans', {
      'folder_path': scan.folderPath,
      'file_count': scan.fileCount,
      'total_size': scan.totalSize,
      'category_counts': jsonEncode(scan.categoryCountsJson),
      'scanned_at': scan.scannedAt.toIso8601String(),
      'duration_ms': scan.duration.inMilliseconds,
    });
  }

  Future<Map<String, Object?>?> latestScanRow() async {
    final rows = await db.query(
      'scans',
      orderBy: 'scanned_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // --- Operations --------------------------------------------------------

  Future<int> nextBatchId() async {
    final rows = await db.rawQuery(
        'SELECT COALESCE(MAX(batch_id), 0) AS max_id FROM operations');
    return ((rows.first['max_id'] as num?) ?? 0).toInt() + 1;
  }

  Future<void> insertOperations(List<MoveOperation> ops) async {
    final batch = db.batch();
    for (final op in ops) {
      batch.insert('operations', {
        'batch_id': op.batchId,
        'file_name': op.fileName,
        'from_path': op.fromPath,
        'to_path': op.toPath,
        'action': op.action,
        'status': op.status,
        'created_at': op.createdAt.toIso8601String(),
        'details': op.details,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<MoveOperation>> operations({int limit = 500}) async {
    final rows = await db.query(
      'operations',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(MoveOperation.fromRow).toList();
  }

  /// Operations belonging to the most recent batch, oldest first, so they
  /// can be undone in reverse order.
  Future<List<MoveOperation>> latestBatchOperations() async {
    final rows = await db.rawQuery('''
      SELECT * FROM operations
      WHERE batch_id = (SELECT MAX(batch_id) FROM operations)
      ORDER BY id ASC
    ''');
    return rows.map(MoveOperation.fromRow).toList();
  }

  Future<void> clearHistory() async {
    await db.delete('operations');
  }

  /// Removes stored scan summaries — regenerable cache used for the
  /// dashboard's "last scan" stats. Operations, rules and preferences are
  /// untouched.
  Future<void> clearScanCache() async {
    await db.delete('scans');
  }

  // --- Rules -------------------------------------------------------------

  Future<List<CustomRule>> rules() async {
    final rows = await db.query('rules', orderBy: 'name COLLATE NOCASE');
    return rows.map(CustomRule.fromRow).toList();
  }

  Future<void> insertRule(CustomRule rule) async {
    await db.insert('rules', {
      'name': rule.name,
      'field': rule.field.name,
      'condition': rule.condition.name,
      'value': rule.value,
      'target_folder': rule.targetFolder,
      'enabled': rule.enabled ? 1 : 0,
      'create_folder': rule.createFolder ? 1 : 0,
    });
  }

  Future<void> updateRule(CustomRule rule) async {
    await db.update('rules', {
      'name': rule.name,
      'field': rule.field.name,
      'condition': rule.condition.name,
      'value': rule.value,
      'target_folder': rule.targetFolder,
      'enabled': rule.enabled ? 1 : 0,
      'create_folder': rule.createFolder ? 1 : 0,
    }, where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<void> deleteRule(int id) async {
    await db.delete('rules', where: 'id = ?', whereArgs: [id]);
  }

  /// Number of organize moves still in effect (organizes minus undos).
  Future<int> organizedFileCount() async {
    final rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN action = 'organize' AND status = 'completed' THEN 1 ELSE 0 END) AS organized,
        SUM(CASE WHEN action = 'undo' AND status = 'completed' THEN 1 ELSE 0 END) AS undone
      FROM operations
    ''');
    final row = rows.first;
    final organized = (row['organized'] as num?)?.toInt() ?? 0;
    final undone = (row['undone'] as num?)?.toInt() ?? 0;
    return organized - undone;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }
}
