import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../database/database_helper.dart';
import 'supabase_config.dart';

/// SyncService — push local unsynced rows to Supabase, pull remote changes.
///
/// Call [sync] whenever connectivity is restored, or on app foreground.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _syncing = false;

  /// Tables to sync, in dependency order (parents before children).
  static const _tables = [
    'warehouses',
    'suppliers',
    'inventory_items',
    'crate_stocks',
    'customers',
    'orders',
    'expenses',
    'deliveries',
    'delivery_receipts',
    'supplier_payments',
    'activity_logs',
    'inventory_logs',
    'notifications',
    'staff',
  ];

  /// Listen for connectivity changes and auto-sync when online.
  void startListening() {
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) sync();
    });
  }

  /// Full bidirectional sync: push then pull for each table.
  Future<void> sync() async {
    if (_syncing || !SupabaseConfig.isConfigured) return;
    _syncing = true;

    try {
      final db = await DatabaseHelper.instance.db;
      for (final table in _tables) {
        await _push(db, table);
        await _pull(db, table);
      }
    } catch (e) {
      // Sync errors are non-fatal — app continues offline
    } finally {
      _syncing = false;
    }
  }

  /// Push all unsynced local rows to Supabase (upsert), then mark synced.
  Future<void> _push(dynamic db, String table) async {
    final rows = await db.query(table, where: 'synced = 0');
    if (rows.isEmpty) return;

    final client = SupabaseConfig.client;

    for (final row in rows) {
      final cleaned = Map<String, dynamic>.from(row)
        ..remove('synced'); // Supabase doesn't need this column

      try {
        if (row['deleted_at'] != null) {
          // Soft-deleted locally → delete on Supabase
          await client.from(table).delete().eq('id', row['id'] as String);
        } else {
          await client.from(table).upsert(cleaned);
        }

        await db.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [row['id']]);
      } catch (_) {
        // Leave synced = 0 to retry next time
      }
    }
  }

  /// Pull rows from Supabase updated after our last sync, upsert locally.
  Future<void> _pull(dynamic db, String table) async {
    final client = SupabaseConfig.client;

    // Get last synced timestamp for this table
    final metaRows = await db.query(
      'sync_meta',
      where: 'table_name = ?',
      whereArgs: [table],
    );
    final lastSynced = metaRows.isNotEmpty
        ? metaRows.first['last_synced_at'] as String
        : '1970-01-01T00:00:00.000Z';

    try {
      final remoteRows = await client
          .from(table)
          .select()
          .gt('updated_at', lastSynced)
          .order('updated_at');

      final now = DateTime.now().toIso8601String();

      for (final row in remoteRows) {
        final local = Map<String, dynamic>.from(row as Map)
          ..['synced'] = 1;

        // Only upsert if remote is newer than local
        final localRows = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [row['id']],
        );

        if (localRows.isEmpty) {
          try {
            await db.insert(table, local, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
        } else {
          final localUpdated = localRows.first['updated_at'] as String? ?? '';
          final remoteUpdated = row['updated_at'] as String? ?? '';
          if (remoteUpdated.compareTo(localUpdated) > 0) {
            await db.update(table, local, where: 'id = ?', whereArgs: [row['id']]);
          }
        }
      }

      // Update sync_meta
      await db.insert(
        'sync_meta',
        {'table_name': table, 'last_synced_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Pull failure is non-fatal
    }
  }
}
