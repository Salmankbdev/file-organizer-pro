/// A persisted record of a file move (organize) or a reversal (undo).
class MoveOperation {
  const MoveOperation({
    this.id,
    required this.batchId,
    required this.fileName,
    required this.fromPath,
    required this.toPath,
    required this.action,
    required this.status,
    required this.createdAt,
  });

  final int? id;

  /// Groups operations applied in a single action so they can be undone
  /// together.
  final int batchId;

  final String fileName;
  final String fromPath;
  final String toPath;

  /// Either `organize` or `undo`.
  final String action;

  /// Either `completed` or `failed`.
  final String status;

  final DateTime createdAt;

  MoveOperation copyWith({String? status}) => MoveOperation(
        id: id,
        batchId: batchId,
        fileName: fileName,
        fromPath: fromPath,
        toPath: toPath,
        action: action,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  factory MoveOperation.fromRow(Map<String, Object?> row) => MoveOperation(
        id: row['id'] as int,
        batchId: row['batch_id'] as int,
        fileName: row['file_name'] as String,
        fromPath: row['from_path'] as String,
        toPath: row['to_path'] as String,
        action: row['action'] as String,
        status: row['status'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
