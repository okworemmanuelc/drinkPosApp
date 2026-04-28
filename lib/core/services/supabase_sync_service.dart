import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of decoding the current Supabase session's access token.
/// `businessId` is non-null only when the JWT actually carries a
/// `business_id` claim (top-level or under `app_metadata` /
/// `user_metadata`). Used by the Sync Issues screen to confirm whether
/// JWT-claim-based RLS will see the right tenant.
class JwtClaimSnapshot {
  final bool hasSession;
  final int? businessId;
  final String? source; // 'top-level' | 'app_metadata' | 'user_metadata'
  final String? error;

  const JwtClaimSnapshot({
    required this.hasSession,
    this.businessId,
    this.source,
    this.error,
  });
}

class SupabaseSyncService {
  final AppDatabase _db;
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _businessesChannel;
  StreamSubscription<int>? _autoPushSub;
  StreamSubscription<AuthState>? _authStateSub;
  Timer? _autoPushDebounce;
  bool _pushing = false;
  bool _loggedJwtClaimsThisSession = false;

  SupabaseSyncService(this._db);

  /// Decodes the current access token's payload (no signature check — this is
  /// purely for local introspection) and reports whether `business_id` is
  /// present. Returns a snapshot the UI can render directly.
  static JwtClaimSnapshot inspectJwtClaims() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const JwtClaimSnapshot(hasSession: false);
    }
    try {
      final parts = session.accessToken.split('.');
      if (parts.length != 3) {
        return const JwtClaimSnapshot(
            hasSession: true, error: 'malformed JWT');
      }
      // base64url-decode the payload segment, padding as needed.
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final json =
          jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;

      int? toInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v);
        return null;
      }

      final top = toInt(json['business_id']);
      if (top != null) {
        return JwtClaimSnapshot(
            hasSession: true, businessId: top, source: 'top-level');
      }
      final appMeta = json['app_metadata'];
      if (appMeta is Map) {
        final v = toInt(appMeta['business_id']);
        if (v != null) {
          return JwtClaimSnapshot(
              hasSession: true, businessId: v, source: 'app_metadata');
        }
      }
      final userMeta = json['user_metadata'];
      if (userMeta is Map) {
        final v = toInt(userMeta['business_id']);
        if (v != null) {
          return JwtClaimSnapshot(
              hasSession: true, businessId: v, source: 'user_metadata');
        }
      }
      return const JwtClaimSnapshot(hasSession: true);
    } catch (e) {
      return JwtClaimSnapshot(hasSession: true, error: e.toString());
    }
  }

  /// Cloud tables that have no `updated_at` column. On push, `last_updated_at`
  /// is dropped (not renamed) from the payload. On pull, the incremental
  /// `since` filter uses `created_at` instead. Mostly append-only logs and
  /// transactions; entries here are confirmed via PostgREST 42703 errors.
  static const _tablesWithoutUpdatedAt = {
    'order_items',
    'wallet_transactions',
    'expenses',
    'expense_categories',
    'delivery_receipts',
    'drivers',
    'stock_transfers',
    'stock_adjustments',
    'activity_logs',
    'notifications',
    'stock_transactions',
    'saved_carts',
    'pending_crate_returns',
    'invites',
  };

  /// Tables whose rows are referenced by FKs from other tables. They must be
  /// pushed before any child rows in the same batch, otherwise the child push
  /// fails with a 23503 FK violation. Lower number = pushed first.
  static const Map<String, int> _tablePushPriority = {
    'businesses': 0,
    'profiles': 1,
    'warehouses': 2,
    'manufacturers': 3,
    'crate_groups': 3,
    'categories': 4,
    'suppliers': 5,
    'products': 10,
    'customers': 11,
    'inventory': 12,
    'customer_wallets': 20,
    'orders': 30,
    'order_items': 31,
    'wallet_transactions': 32,
  };

  int _priorityFor(String actionType) {
    final table = actionType.split(':').first;
    return _tablePushPriority[table] ?? 100;
  }

  /// Translates a locally-built payload into the column names the cloud schema
  /// actually exposes. Local Drift uses `lastUpdatedAt`; cloud uses `updated_at`
  /// (or no equivalent). Products store the manufacturer display string in
  /// `manufacturer` locally but the cloud column is `manufacturer_name`.
  Map<String, dynamic> _normalizePayloadForCloud(
      String table, Map<String, dynamic> payload) {
    final out = Map<String, dynamic>.from(payload);
    if (out.containsKey('last_updated_at')) {
      out['updated_at'] = out.remove('last_updated_at');
    }
    if (_tablesWithoutUpdatedAt.contains(table)) {
      out.remove('updated_at');
    }
    if (table == 'products' && out.containsKey('manufacturer')) {
      out['manufacturer_name'] = out.remove('manufacturer');
    }
    return out;
  }

  /// Pushes all pending local changes to Supabase.
  Future<void> pushPending() async {
    // Without an authenticated session the server sees auth.uid() as NULL,
    // so RLS denies every insert. Skip rather than burn `attempts` and rack
    // up false negatives — startAutoPush retriggers as soon as sign-in lands.
    if (_supabase.auth.currentUser == null) {
      debugPrint('[SyncService] Skipping push: no auth session.');
      return;
    }

    if (!_loggedJwtClaimsThisSession) {
      _loggedJwtClaimsThisSession = true;
      final claims = inspectJwtClaims();
      // Informational only. This project's RLS uses auth.uid() → profiles
      // via get_user_business_id(); JWT claims are not consulted. See
      // supabase/rls_snapshot.md.
      if (claims.businessId != null) {
        debugPrint('[SyncService] JWT business_id=${claims.businessId} '
            '(via ${claims.source}, informational — RLS uses profiles join).');
      } else if (claims.error != null) {
        debugPrint('[SyncService] JWT decode failed: ${claims.error}');
      } else {
        debugPrint('[SyncService] JWT has no business_id claim '
            '(expected — RLS resolves business_id via profiles join).');
      }
    }

    // Filter the queue to the current session's tenant. The v36 schema makes
    // every sync_queue row carry a businessId; the resolver hung off
    // AppDatabase carries the session's businessId after AuthService wires it
    // up at login. If still null here we cannot safely push (would risk
    // pushing another tenant's row), so bail.
    final sessionBusinessId = _db.currentBusinessId;
    if (sessionBusinessId == null) {
      debugPrint('[SyncService] Skipping push: no session businessId.');
      return;
    }

    final pendingItems = await _db.syncDao.getPendingItems(
      limit: 50,
      businessId: sessionBusinessId,
    );
    if (pendingItems.isEmpty) return;

    // Order by table priority so parent rows (warehouses, businesses, …) are
    // pushed before any child rows that reference them by FK. Within a single
    // priority bucket, fall back to insertion order (id ASC).
    pendingItems.sort((a, b) {
      final pa = _priorityFor(a.actionType);
      final pb = _priorityFor(b.actionType);
      if (pa != pb) return pa.compareTo(pb);
      return a.id.compareTo(b.id);
    });

    debugPrint('[SyncService] Pushing ${pendingItems.length} items to Supabase...');

    for (final item in pendingItems) {
      await _db.syncDao.markInProgress(item.id);
      try {
        final rawPayload = jsonDecode(item.payload) as Map<String, dynamic>;
        // Format: "table_name:action" or "table_name:action:conflict_col1,conflict_col2"
        // The optional third segment overrides the default upsert PK ('id') for
        // tables with composite primary keys, e.g. customer_crate_balances.
        final parts = item.actionType.split(':');
        final tableName = parts[0];
        final action = parts[1];
        final conflictTarget = parts.length > 2 ? parts[2] : null;

        // Post-v36 invariant: enqueue() requires a businessId, and the queue
        // is filtered by sessionBusinessId above. A row reaching this point
        // with a missing/mismatched tenant marker is a programming error.
        final payloadBusinessId = rawPayload['business_id'];
        if (item.businessId != sessionBusinessId ||
            payloadBusinessId == null ||
            (payloadBusinessId is num && payloadBusinessId.toInt() != sessionBusinessId)) {
          debugPrint('[SyncService] Hard-fail item ${item.id} (${item.actionType}): '
              'tenant mismatch (row=${item.businessId} payload=$payloadBusinessId session=$sessionBusinessId)');
          await _db.syncDao.markFailed(item.id, 'tenant_mismatch_post_filter');
          continue;
        }

        final payload = _normalizePayloadForCloud(tableName, rawPayload);

        if (action == 'insert' || action == 'update' || action == 'upsert') {
          if (conflictTarget != null) {
            await _supabase.from(tableName).upsert(payload, onConflict: conflictTarget);
          } else {
            await _supabase.from(tableName).upsert(payload);
          }
        } else if (action == 'delete') {
          // Soft delete is handled by update (is_deleted = true)
          // Hard delete would use .delete()
          await _supabase.from(tableName).delete().match({'id': payload['id']});
        }

        await _db.syncDao.markDone(item.id);
      } catch (e) {
        debugPrint('[SyncService] Failed to push item ${item.id}: $e');
        await _db.syncDao.markFailed(item.id, e.toString());
      }
    }

    // Recursively call if there might be more items
    if (pendingItems.length == 50) {
      await pushPending();
    }
  }

  /// Orchestrates a two-way sync: push local changes, then pull cloud updates.
  Future<void> syncAll(int businessId) async {
    debugPrint('[SyncService] Starting two-way sync for business $businessId...');
    try {
      await pushPending();
      
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('last_sync_timestamp');
      DateTime? since;
      if (lastSyncStr != null) {
        since = DateTime.tryParse(lastSyncStr);
      }
      
      await pullInitialData(businessId, since: since);
      
      await prefs.setString('last_sync_timestamp', DateTime.now().toUtc().toIso8601String());
      debugPrint('[SyncService] Two-way sync completed successfully.');
    } catch (e) {
      debugPrint('[SyncService] Sync failed: $e');
      rethrow;
    }
  }

  /// Pulls data for the current business from Supabase and populates the local DB.
  /// If [since] is provided, performs an incremental pull.
  Future<void> pullInitialData(int businessId, {DateTime? since}) async {
    debugPrint('[SyncService] Pulling data for business $businessId (since: ${since?.toIso8601String() ?? "beginning"})...');

    // List of tables to sync (order matters for FK constraints).
    // `crates` removed — cloud schema has only `crate_groups`.
    final syncOrder = [
      'businesses',
      'crate_groups',
      'manufacturers',
      'warehouses',
      'profiles',
      'categories',
      'products',
      'inventory',
      'customers',
      'suppliers',
      'orders',
      'order_items',
      'expenses',
      'expense_categories',
      'customer_crate_balances',
      'delivery_receipts',
      'drivers',
      'stock_transfers',
      'stock_adjustments',
      'activity_logs',
      'notifications',
      'stock_transactions',
      'customer_wallets',
      'wallet_transactions',
      'saved_carts',
      'pending_crate_returns',
      'invites',
    ];

    for (final table in syncOrder) {
      try {
        // The cloud `businesses` table has no `business_id` column — its `id`
        // IS the business id. All other tables filter by `business_id`.
        final filterColumn = table == 'businesses' ? 'id' : 'business_id';
        var query =
            _supabase.from(table).select().eq(filterColumn, businessId);

        if (since != null) {
          // Cloud tables that have no `updated_at` column fall back to
          // `created_at` for incremental pulls. These are mostly
          // append-only logs/transactions; updates on them won't be
          // delivered incrementally, but pulling everything each time
          // would scale poorly.
          final filter =
              _tablesWithoutUpdatedAt.contains(table) ? 'created_at' : 'updated_at';
          query = query.gt(filter, since.toIso8601String());
        }

        final data = await query;

        if (data.isNotEmpty) {
          debugPrint('[SyncService] Syncing $table: ${data.length} rows');
          await _restoreTableData(table, data);
        }
      } catch (e) {
        debugPrint('[SyncService] Error pulling table $table: $e');
      }
    }
  }

  /// Subscribes to real-time changes from Supabase for this business.
  void startRealtimeSync(int businessId) {
    if (_realtimeChannel != null) return;

    debugPrint('[SyncService] Starting real-time sync for business $businessId');

    // Wildcard subscription for all tables with a `business_id` column.
    // The `businesses` table has no `business_id` and is handled separately.
    // Per-table refactor deferred — wrap in try/catch so a single bad table
    // doesn't kill the whole channel.
    try {
      _realtimeChannel = _supabase.channel('public:*').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_id',
          value: businessId,
        ),
        callback: (payload) async {
          debugPrint('[SyncService] Realtime Event: ${payload.eventType} on ${payload.table}');

          final table = payload.table;
          final newRecord = payload.newRecord;

          if (newRecord.isNotEmpty) {
            await _restoreTableData(table, [newRecord]);
          } else if (payload.eventType == PostgresChangeEvent.delete &&
              payload.oldRecord.isNotEmpty) {
            final id = payload.oldRecord['id'];
            if (id != null) {
              // For now, soft deletes are handled as updates.
            }
          }
        },
      )..subscribe();
    } catch (e) {
      debugPrint('[SyncService] Wildcard realtime subscribe failed: $e');
    }

    // Separate channel for `businesses` filtered by `id` (no business_id column).
    try {
      _businessesChannel = _supabase.channel('public:businesses').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'businesses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: businessId,
        ),
        callback: (payload) async {
          debugPrint('[SyncService] Realtime Event: ${payload.eventType} on businesses');
          final newRecord = payload.newRecord;
          if (newRecord.isNotEmpty) {
            await _restoreTableData('businesses', [newRecord]);
          }
        },
      )..subscribe();
    } catch (e) {
      debugPrint('[SyncService] Businesses realtime subscribe failed: $e');
    }
  }

  /// Stops listening to real-time changes (e.g., on logout).
  void stopRealtimeSync() {
    debugPrint('[SyncService] Stopping real-time sync.');
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    if (_businessesChannel != null) {
      _supabase.removeChannel(_businessesChannel!);
      _businessesChannel = null;
    }
    stopAutoPush();
  }

  /// Watches the local sync queue and pushes pending items to Supabase
  /// shortly after they are enqueued. Idempotent — safe to call repeatedly.
  bool _autoPushStarting = false;

  void startAutoPush() {
    if (_autoPushSub != null || _autoPushStarting) return;
    _autoPushStarting = true;
    unawaited(_initAutoPush());
  }

  /// Sequential initialization. The previous implementation fired the
  /// backfill, backoff-clear and listener subscription in parallel as
  /// `unawaited` futures, which raced: the first push tick could load the
  /// queue before the warehouse backfill INSERT had committed, so the
  /// warehouse was missing and the customer/wallet FK-failed against a
  /// cloud row that didn't exist yet. Awaiting the prep work in order
  /// guarantees the queue is in its final state before we subscribe.
  Future<void> _initAutoPush() async {
    try {
      await _db.syncDao.resetStuckInProgress();
      await _backfillUnsyncedWarehouses();

      if (_supabase.auth.currentUser != null) {
        await _db.syncDao.clearFailureBackoff();
      }

      _autoPushSub = _db.syncDao.watchPendingCount().listen((count) {
        if (count == 0) return;
        _scheduleDebouncedPush();
      });

      _authStateSub ??= _supabase.auth.onAuthStateChange.listen((state) async {
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.initialSession) {
          _loggedJwtClaimsThisSession = false;
          await _db.syncDao.clearFailureBackoff();
          _scheduleDebouncedPush();
        } else if (state.event == AuthChangeEvent.signedOut) {
          _loggedJwtClaimsThisSession = false;
        }
      });
    } finally {
      _autoPushStarting = false;
    }
  }

  void _scheduleDebouncedPush() {
    _autoPushDebounce?.cancel();
    _autoPushDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (_pushing) return;
      _pushing = true;
      try {
        await pushPending();
      } catch (e) {
        debugPrint('[SyncService] auto-push failed: $e');
      } finally {
        _pushing = false;
      }
    });
  }

  /// Enqueues an upsert for any warehouse that has never been synced
  /// (`lastUpdatedAt IS NULL`). Onboarding originally inserted warehouses
  /// without going through the sync queue, leaving customer/product FKs
  /// dangling in the cloud. Idempotent: marking `lastUpdatedAt` after
  /// enqueueing prevents re-queueing on subsequent startups.
  Future<void> _backfillUnsyncedWarehouses() async {
    try {
      final whs = await (_db.select(_db.warehouses)
            ..where((t) => t.lastUpdatedAt.isNull()))
          .get();
      if (whs.isEmpty) return;

      // Some onboarding paths inserted warehouses before the user's
      // businessId was hydrated, leaving businessId NULL. Such warehouses
      // are unsyncable as-is (cloud RLS requires business_id) AND the
      // customer rows that reference them will FK-fail. Patch them to the
      // current auth user's businessId before enqueuing.
      int? fallbackBusinessId;
      final authEmail = _supabase.auth.currentUser?.email;
      if (authEmail != null) {
        final localUser = await (_db.select(_db.users)
              ..where((u) => u.email.equals(authEmail)))
            .getSingleOrNull();
        fallbackBusinessId = localUser?.businessId;
      }

      final now = DateTime.now();
      var enqueued = 0;
      var skipped = 0;
      for (final w in whs) {
        var businessId = w.businessId;
        if (businessId == null) {
          if (fallbackBusinessId == null) {
            skipped++;
            continue;
          }
          await (_db.update(_db.warehouses)..where((t) => t.id.equals(w.id)))
              .write(WarehousesCompanion(businessId: Value(fallbackBusinessId)));
          businessId = fallbackBusinessId;
        }
        await _db.syncDao.enqueue(
          'warehouses:upsert',
          jsonEncode({
            'id': w.id,
            'business_id': businessId,
            'name': w.name,
            'location': w.location,
            'last_updated_at': now.toIso8601String(),
            'is_deleted': w.isDeleted,
          }),
          businessId: businessId,
        );
        await (_db.update(_db.warehouses)..where((t) => t.id.equals(w.id)))
            .write(WarehousesCompanion(lastUpdatedAt: Value(now)));
        enqueued++;
      }
      if (enqueued > 0 || skipped > 0) {
        debugPrint('[SyncService] Warehouse backfill: '
            'enqueued=$enqueued skipped=$skipped');
      }
    } catch (e) {
      debugPrint('[SyncService] Warehouse backfill failed: $e');
    }
  }

  void stopAutoPush() {
    _autoPushDebounce?.cancel();
    _autoPushDebounce = null;
    _autoPushSub?.cancel();
    _autoPushSub = null;
    _authStateSub?.cancel();
    _authStateSub = null;
  }

  /// Converts snake_case Supabase JSON keys to camelCase for Drift's fromJson.
  Map<String, dynamic> _snakeToCamel(Map<String, dynamic> m) {
    return m.map((key, value) {
      final camel = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      return MapEntry(camel, value);
    });
  }

  /// Maps Supabase table names to Drift insertion logic.
  /// Uses DataClass.fromJson() which is always generated by Drift,
  /// then inserts the DataClass directly since it implements Insertable.
  Future<void> _restoreTableData(String table, List<dynamic> data) async {
    final rows = data.map((e) => _snakeToCamel(e as Map<String, dynamic>)).toList();

    await _db.transaction(() async {
      switch (table) {
        case 'businesses':
          for (var r in rows) {
            await _db.into(_db.businesses).insertOnConflictUpdate(BusinessData.fromJson(r));
          }
          break;
        case 'warehouses':
          for (var r in rows) {
            await _db.into(_db.warehouses).insertOnConflictUpdate(WarehouseData.fromJson(r));
          }
          break;
        case 'profiles':
          // No-op: cloud `profiles` has no email column, so multi-user backfill
          // here is unreliable. The current user's local row is upserted via
          // AuthService.upsertLocalUserFromProfile() during the auth flow.
          debugPrint('[SyncService] Skipping bulk profiles restore (${rows.length} rows) — handled by auth flow.');
          break;
        case 'products':
          for (var r in rows) {
            await _db.into(_db.products).insertOnConflictUpdate(ProductData.fromJson(r));
          }
          break;
        case 'crate_groups':
          for (var r in rows) {
            await _db.into(_db.crateGroups).insertOnConflictUpdate(CrateGroupData.fromJson(r));
          }
          break;
        case 'manufacturers':
          for (var r in rows) {
            await _db.into(_db.manufacturers).insertOnConflictUpdate(ManufacturerData.fromJson(r));
          }
          break;
        case 'categories':
          for (var r in rows) {
            await _db.into(_db.categories).insertOnConflictUpdate(CategoryData.fromJson(r));
          }
          break;
        case 'inventory':
          for (var r in rows) {
            await _db.into(_db.inventory).insertOnConflictUpdate(InventoryData.fromJson(r));
          }
          break;
        case 'customers':
          for (var r in rows) {
            await _db.into(_db.customers).insertOnConflictUpdate(CustomerData.fromJson(r));
          }
          break;
        case 'suppliers':
          for (var r in rows) {
            await _db.into(_db.suppliers).insertOnConflictUpdate(SupplierData.fromJson(r));
          }
          break;
        case 'orders':
          for (var r in rows) {
            await _db.into(_db.orders).insertOnConflictUpdate(OrderData.fromJson(r));
          }
          break;
        case 'order_items':
          for (var r in rows) {
            await _db.into(_db.orderItems).insertOnConflictUpdate(OrderItemData.fromJson(r));
          }
          break;
        case 'expenses':
          for (var r in rows) {
            await _db.into(_db.expenses).insertOnConflictUpdate(ExpenseData.fromJson(r));
          }
          break;
        case 'expense_categories':
          for (var r in rows) {
            await _db.into(_db.expenseCategories).insertOnConflictUpdate(ExpenseCategoryData.fromJson(r));
          }
          break;
        case 'crates':
          for (var r in rows) {
            await _db.into(_db.crates).insertOnConflictUpdate(CrateData.fromJson(r));
          }
          break;
        case 'customer_crate_balances':
          for (var r in rows) {
            await _db.into(_db.customerCrateBalances).insertOnConflictUpdate(CustomerCrateBalance.fromJson(r));
          }
          break;
        case 'delivery_receipts':
          for (var r in rows) {
            await _db.into(_db.deliveryReceipts).insertOnConflictUpdate(DeliveryReceiptData.fromJson(r));
          }
          break;
        case 'drivers':
          for (var r in rows) {
            await _db.into(_db.drivers).insertOnConflictUpdate(DriverData.fromJson(r));
          }
          break;
        case 'price_lists':
          for (var r in rows) {
            await _db.into(_db.priceLists).insertOnConflictUpdate(PriceListData.fromJson(r));
          }
          break;
        case 'payment_transactions':
          for (var r in rows) {
            await _db.into(_db.paymentTransactions).insertOnConflictUpdate(PaymentTransactionData.fromJson(r));
          }
          break;
        case 'stock_transfers':
          for (var r in rows) {
            await _db.into(_db.stockTransfers).insertOnConflictUpdate(StockTransferData.fromJson(r));
          }
          break;
        case 'stock_adjustments':
          for (var r in rows) {
            await _db.into(_db.stockAdjustments).insertOnConflictUpdate(StockAdjustmentData.fromJson(r));
          }
          break;
        case 'activity_logs':
          for (var r in rows) {
            await _db.into(_db.activityLogs).insertOnConflictUpdate(ActivityLogData.fromJson(r));
          }
          break;
        case 'notifications':
          for (var r in rows) {
            await _db.into(_db.notifications).insertOnConflictUpdate(NotificationData.fromJson(r));
          }
          break;
        case 'settings':
          for (var r in rows) {
            await _db.into(_db.settings).insertOnConflictUpdate(SettingData.fromJson(r));
          }
          break;
        case 'sessions':
          for (var r in rows) {
            await _db.into(_db.sessions).insertOnConflictUpdate(SessionData.fromJson(r));
          }
          break;
        case 'customer_wallet_transactions':
          for (var r in rows) {
            await _db.into(_db.customerWalletTransactions).insertOnConflictUpdate(CustomerWalletTransactionData.fromJson(r));
          }
          break;
        case 'stock_transactions':
          for (var r in rows) {
            await _db.into(_db.stockTransactions).insertOnConflictUpdate(StockTransactionData.fromJson(r));
          }
          break;
        case 'customer_wallets':
          for (var r in rows) {
            await _db.into(_db.customerWallets).insertOnConflictUpdate(CustomerWalletData.fromJson(r));
          }
          break;
        case 'wallet_transactions':
          for (var r in rows) {
            await _db.into(_db.walletTransactions).insertOnConflictUpdate(WalletTransactionData.fromJson(r));
          }
          break;
        case 'saved_carts':
          for (var r in rows) {
            await _db.into(_db.savedCarts).insertOnConflictUpdate(SavedCartData.fromJson(r));
          }
          break;
        case 'pending_crate_returns':
          for (var r in rows) {
            await _db.into(_db.pendingCrateReturns).insertOnConflictUpdate(PendingCrateReturnData.fromJson(r));
          }
          break;
        case 'invites':
          for (var r in rows) {
            await _db.into(_db.invites).insertOnConflictUpdate(InviteData.fromJson(r));
          }
          break;
        default:
          debugPrint('[SyncService] Restore logic not implemented for $table');
      }
    });
  }
}

