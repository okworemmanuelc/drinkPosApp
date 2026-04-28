import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/utils/logger.dart';

/// Wraps each migration step so failures stop being silent. Replaces the
/// scattered `try { ... } catch (_) {}` blocks in [AppDatabase] migrations.
///
/// - Idempotent re-runs (column or table already exists) → log `warning`,
///   swallow.
/// - Anything else → log `error`, rethrow so Drift's transaction rolls back
///   and `user_version` does not advance past a half-applied state.
///
/// Critical errors are also appended to a flat-file `migration_events.jsonl`
/// next to the schema-audit reports — the in-DB write rolls back with the
/// failed transaction, but the flat file survives so [SchemaAudit] can
/// surface the failure on the next boot.
class MigrationLogger {
  final AppDatabase db;
  MigrationLogger(this.db);

  /// Run [body]. On success: nothing recorded. On already-exists error:
  /// logged as a `warning` and swallowed. On any other error: logged as an
  /// `error` (DB + jsonl) and rethrown.
  Future<void> runStep({
    required int version,
    required String step,
    required Future<void> Function() body,
    bool tolerateAlreadyExists = true,
  }) async {
    try {
      await body();
    } catch (e) {
      if (tolerateAlreadyExists && _isAlreadyExistsError(e)) {
        await _record(
          version: version,
          step: step,
          severity: 'warning',
          errorMessage: e.toString(),
        );
        return;
      }
      await _record(
        version: version,
        step: step,
        severity: 'error',
        errorMessage: e.toString(),
      );
      await _writeFlatFile(
        version: version,
        step: step,
        severity: 'error',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// True for SQLite errors raised when re-adding a column or re-creating a
  /// table that already exists. These are expected on idempotent migration
  /// re-runs (e.g. v22 and v23 both add `users.createdAt`).
  bool _isAlreadyExistsError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('duplicate column name') ||
        msg.contains('already exists');
  }

  /// Best-effort insert into `migration_events`. Failures here (e.g. table
  /// doesn't exist yet on a very fresh DB) fall back to AppLogger and are
  /// swallowed — the migration step itself must not fail because telemetry
  /// failed.
  Future<void> _record({
    required int version,
    required String step,
    required String severity,
    String? errorMessage,
  }) async {
    try {
      await db.customInsert(
        'INSERT INTO migration_events '
        '(version, step, severity, error_message, occurred_at) '
        'VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withInt(version),
          Variable.withString(step),
          Variable.withString(severity),
          if (errorMessage != null)
            Variable.withString(errorMessage)
          else
            const Variable<String>(null),
          Variable.withDateTime(DateTime.now()),
        ],
      );
    } catch (e) {
      AppLogger.error(
        '[MigrationLogger] failed to record event v$version $step', e,
      );
    }
  }

  /// Append a critical event to a JSONL file outside the SQLite transaction.
  /// Survives the rollback that follows a rethrown error.
  Future<void> _writeFlatFile({
    required int version,
    required String step,
    required String severity,
    String? errorMessage,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docsDir.path, 'diagnostics'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(p.join(dir.path, 'migration_events.jsonl'));
      final line = jsonEncode({
        'version': version,
        'step': step,
        'severity': severity,
        'error_message': errorMessage,
        'occurred_at': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      });
      await file.writeAsString('$line\n', mode: FileMode.append);
    } catch (e) {
      AppLogger.error(
        '[MigrationLogger] failed to write flat file v$version $step', e,
      );
    }
  }
}
