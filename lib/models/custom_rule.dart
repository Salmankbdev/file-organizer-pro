import 'scanned_file.dart';

/// What part of the file the rule inspects.
enum RuleField {
  extension('Extension'),
  name('File name');

  const RuleField(this.label);
  final String label;

  static RuleField fromName(String name) =>
      values.firstWhere((f) => f.name == name, orElse: () => RuleField.name);
}

/// How the rule compares the field against [CustomRule.value].
enum RuleCondition {
  is_('is'),
  contains('contains'),
  startsWith('starts with'),
  endsWith('ends with');

  const RuleCondition(this.label);
  final String label;

  static RuleCondition fromName(String name) => values.firstWhere(
      (c) => c.name == name,
      orElse: () => RuleCondition.contains);
}

/// A user-defined rule, e.g. "IF filename contains invoice THEN move to
/// Documents/Invoices". Rules are applied before the default category
/// mapping when organizing a folder.
class CustomRule {
  const CustomRule({
    this.id,
    required this.name,
    required this.field,
    required this.condition,
    required this.value,
    required this.targetFolder,
    this.enabled = true,
    this.createFolder = true,
  });

  final int? id;
  final String name;
  final RuleField field;
  final RuleCondition condition;

  /// The text to match against (extension without dot for [RuleField.extension]).
  final String value;

  /// Destination for matching files. Relative paths are resolved inside the
  /// scanned folder (e.g. `Documents/Invoices`); absolute paths (e.g.
  /// `D:/Invoices`) are used as-is and must not be a protected system folder.
  final String targetFolder;

  final bool enabled;

  /// When false, matching files are only routed to [targetFolder] if the
  /// folder already exists; otherwise they fall through to the default
  /// category mapping (the rule never creates new folders).
  final bool createFolder;

  CustomRule copyWith({
    int? id,
    String? name,
    RuleField? field,
    RuleCondition? condition,
    String? value,
    String? targetFolder,
    bool? enabled,
    bool? createFolder,
  }) =>
      CustomRule(
        id: id ?? this.id,
        name: name ?? this.name,
        field: field ?? this.field,
        condition: condition ?? this.condition,
        value: value ?? this.value,
        targetFolder: targetFolder ?? this.targetFolder,
        enabled: enabled ?? this.enabled,
        createFolder: createFolder ?? this.createFolder,
      );

  /// Whether [file] satisfies this rule.
  bool matches(ScannedFile file) {
    switch (field) {
      case RuleField.extension:
        // Only the `is` condition makes sense for extensions.
        if (condition != RuleCondition.is_) return false;
        final ext = value.replaceFirst('.', '').trim().toLowerCase();
        return ext.isNotEmpty && file.extension == ext;
      case RuleField.name:
        final needle = value.toLowerCase();
        final haystack = file.name.toLowerCase();
        switch (condition) {
          case RuleCondition.is_:
            return haystack == needle;
          case RuleCondition.contains:
            return haystack.contains(needle);
          case RuleCondition.startsWith:
            return haystack.startsWith(needle);
          case RuleCondition.endsWith:
            return haystack.endsWith(needle);
        }
    }
  }

  factory CustomRule.fromRow(Map<String, Object?> row) => CustomRule(
        id: row['id'] as int,
        name: row['name'] as String,
        field: RuleField.fromName(row['field'] as String),
        condition: RuleCondition.fromName(row['condition'] as String),
        value: row['value'] as String,
        targetFolder: row['target_folder'] as String,
        enabled: (row['enabled'] as int) == 1,
        createFolder: ((row['create_folder'] as int?) ?? 1) == 1,
      );
}
