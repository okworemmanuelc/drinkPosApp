import 'package:drift/drift.dart';

/// Converts a camelCase string to snake_case. If the string already contains
/// underscores or contains no uppercase letters, it is returned as is.
String camelToSnake(String input) {
  if (input.contains('_')) return input;
  final exp = RegExp(r'(?<=[a-z0-9])([A-Z])');
  return input.replaceAllMapped(exp, (m) => '_${m.group(1)!}').toLowerCase();
}

/// Robust serialization helper to extract cloud-ready key-value maps
/// from any Drift `Insertable` (supporting both `DataClass` and `Companion`).
Map<String, dynamic> serializeInsertable(Insertable row) {
  final Map<String, dynamic> rawMap;
  if (row is DataClass) {
    rawMap = (row as dynamic).toJson() as Map<String, dynamic>;
  } else {
    final columns = row.toColumns(true);
    rawMap = columns.map((k, v) {
      if (v is Variable) {
        return MapEntry(k, v.value);
      } else if (v is Constant) {
        return MapEntry(k, v.value);
      } else {
        return MapEntry(k, null);
      }
    });
  }

  // Convert keys to snake_case and format DateTime to UTC ISO-8601 strings
  return rawMap.map((k, v) {
    final snakeKey = camelToSnake(k);
    var val = v;
    if (val is DateTime) {
      val = val.toUtc().toIso8601String();
    }
    return MapEntry(snakeKey, val);
  });
}
