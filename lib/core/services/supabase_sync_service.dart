import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown by [SupabaseSyncService.flushSale] when a `domain:pos_record_sale`
/// envelope fails permanently at the server (insufficient_stock, FK / unique
/// violation, tenant mismatch). The local optimistic sale has already
/// committed; the caller is responsible for compensating (cancelling the
/// order, refunding stock, voiding ledgers) and surfacing to the UI.
class SaleSyncException implements Exception {
  final String orderId;
  final String errorMessage;
  const SaleSyncException({
    required this.orderId,
    required this.errorMessage,
  });
  @override
  String toString() => 'SaleSyncException(orderId=$orderId): $errorMessage';
}

/// Result of decoding the current Supabase session's access token.
/// `businessId` is non-null only when the JWT actually carries a
/// `business_id` claim (top-level or under `app_metadata` /
/// `user_metadata`). Used by the Sync Issues screen to confirm whether
/// JWT-claim-based RLS will see the right tenant.
class JwtClaimSnapshot {
  final bool hasSession;
  final String? businessId;
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _autoPushDebounce;
  bool _pushing = false;
  bool _loggedJwtClaimsThisSession = false;

  /// Connectivity signal driven by `Connectivity().onConnectivityChanged`.
  /// Surfaced to the UI so the drawer's "Syncing…" badge can flip to
  /// "Offline — N queued" when there's no network. Defaults to true so the
  /// app doesn't render an "offline" badge before the first connectivity
  /// event arrives.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  SupabaseSyncService(this._db);

  /// Wired by AuthService to expose this device's active session id so
  /// the Realtime callback can recognise when its own row was revoked.
  String? Function()? currentSessionIdResolver;

  /// Wired by AuthService. Invoked when the Realtime callback observes
  /// the current session row being revoked by another device.
  VoidCallback? onCurrentSessionRevoked;

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
        return const JwtClaimSnapshot(hasSession: true, error: 'malformed JWT');
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
          jsonDecode(utf8.decode(base64.decode(payload)))
              as Map<String, dynamic>;

      String? toStringVal(dynamic v) {
        if (v == null) return null;
        return v.toString();
      }

      final top = toStringVal(json['business_id']);
      if (top != null) {
        return JwtClaimSnapshot(
          hasSession: true,
          businessId: top,
          source: 'top-level',
        );
      }
      final appMeta = json['app_metadata'];
      if (appMeta is Map) {
        final v = toStringVal(appMeta['business_id']);
        if (v != null) {
          return JwtClaimSnapshot(
            hasSession: true,
            businessId: v,
            source: 'app_metadata',
          );
        }
      }
      final userMeta = json['user_metadata'];
      if (userMeta is Map) {
        final v = toStringVal(userMeta['business_id']);
        if (v != null) {
          return JwtClaimSnapshot(
            hasSession: true,
            businessId: v,
            source: 'user_metadata',
          );
        }
      }
      return const JwtClaimSnapshot(hasSession: true);
    } catch (e) {
      return JwtClaimSnapshot(hasSession: true, error: e.toString());
    }
  }

  // Per migration 0001_initial.sql line 12, every synced table uses
  // `last_updated_at` (timestamptz, NOT NULL DEFAULT now()) and the
  // `bump_last_updated_at` trigger fires on every UPDATE. There is no
  // `updated_at` column anywhere in the cloud schema, so we send
  // `last_updated_at` as-is on push and filter by it on pull.

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
    'crate_ledger': 33,
    'manufacturer_crate_balances': 34,
    'system_config': 50,
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
    String table,
    Map<String, dynamic> payload,
  ) {
    final out = Map<String, dynamic>.from(payload);

    // Scrub local-only auth fields from profiles/users
    if (table == 'profiles' || table == 'users') {
      out.remove('pin');
      out.remove('password_hash');
      out.remove('pin_salt');
      out.remove('pin_iterations');
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
        debugPrint(
          '[SyncService] JWT business_id=${claims.businessId} '
          '(via ${claims.source}, informational — RLS uses profiles join).',
        );
      } else if (claims.error != null) {
        debugPrint('[SyncService] JWT decode failed: ${claims.error}');
      } else {
        debugPrint(
          '[SyncService] JWT has no business_id claim '
          '(expected — RLS resolves business_id via profiles join).',
        );
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

    final rawItems = await _db.syncDao.getPendingItems(limit: 200);
    if (rawItems.isEmpty) return;

    // Coalesce duplicates: a burst of writes to the same row (e.g. five
    // inventory adjustments to the same product before the queue drains)
    // only needs the *latest* payload — earlier entries are stale. Keyed by
    // (actionType, payload.id). Earlier rows are immediately marked done
    // since the later payload subsumes them.
    final pendingItems = <SyncQueueData>[];
    final superseded = <String>[];
    final latestByKey = <String, SyncQueueData>{};
    for (final item in rawItems) {
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(item.payload) as Map<String, dynamic>;
      } catch (_) {
        // Undecodable payloads still need to drain through the failure path.
        pendingItems.add(item);
        continue;
      }
      final rowId = payload['id'];
      if (rowId is! String) {
        pendingItems.add(item);
        continue;
      }
      final key = '${item.actionType}|$rowId';
      final prior = latestByKey[key];
      if (prior == null || item.createdAt.isAfter(prior.createdAt)) {
        if (prior != null) superseded.add(prior.id);
        latestByKey[key] = item;
      } else {
        superseded.add(item.id);
      }
    }
    pendingItems.addAll(latestByKey.values);
    if (superseded.isNotEmpty) {
      await _db.syncDao.markDoneBatch(superseded);
    }
    if (pendingItems.isEmpty) return;

    // Partition off domain envelopes: each `domain:<rpc>` row is an atomic
    // multi-table call routed through Postgres functions (see migration
    // 0006_domain_rpcs.sql). They are not batched against each other — each
    // one is an independent transaction — so they bypass the per-table
    // grouping path entirely.
    final domainItems = <SyncQueueData>[];
    final tableItems = <SyncQueueData>[];
    for (final item in pendingItems) {
      if (item.actionType.startsWith('domain:')) {
        domainItems.add(item);
      } else {
        tableItems.add(item);
      }
    }

    if (domainItems.isNotEmpty) {
      await _pushDomainItems(domainItems, sessionBusinessId);
    }

    // Group items by their action signature (table + action + optional
    // conflict target). One Supabase round-trip per group, batched as an
    // array. PostgREST's array-upsert preserves partial-row semantics: only
    // columns present in each payload are updated, so partial Drift
    // Companions (e.g. markCompleted writing only {status, completed_at})
    // don't NULL-out untouched columns.
    final groups = <_PushGroup, List<SyncQueueData>>{};
    for (final item in tableItems) {
      final parts = item.actionType.split(':');
      if (parts.length < 2) continue;
      final group = _PushGroup(
        table: parts[0],
        action: parts[1],
        conflictTarget: parts.length > 2 ? parts[2] : null,
      );
      groups.putIfAbsent(group, () => []).add(item);
    }

    // Order groups by FK priority so parent tables (warehouses, businesses,
    // …) are pushed before children. Within a priority bucket, order is
    // arbitrary — children share their parent's priority bucket only if
    // they truly don't depend on each other.
    final orderedGroups = groups.keys.toList()
      ..sort(
        (a, b) => _priorityFor('${a.table}:${a.action}')
            .compareTo(_priorityFor('${b.table}:${b.action}')),
      );

    debugPrint(
      '[SyncService] Pushing ${pendingItems.length} items in '
      '${orderedGroups.length} batched calls...',
    );

    for (final group in orderedGroups) {
      final items = groups[group]!;
      final ids = items.map((i) => i.id).toList();
      await _db.syncDao.markInProgressBatch(ids);

      // Validate every payload's tenant. Any tenant-mismatch in the group
      // is a programming error; hard-fail just those items and continue.
      final validPayloads = <Map<String, dynamic>>[];
      final validIds = <String>[];
      final mismatchedIds = <String>[];
      for (final item in items) {
        try {
          final raw = jsonDecode(item.payload) as Map<String, dynamic>;
          final pid = raw['business_id'];
          if (item.businessId != sessionBusinessId ||
              pid == null ||
              (pid is String && pid != sessionBusinessId)) {
            mismatchedIds.add(item.id);
            continue;
          }
          validPayloads.add(_normalizePayloadForCloud(group.table, raw));
          validIds.add(item.id);
        } catch (e) {
          await _db.syncDao.markFailed(item.id, 'decode_error: $e');
        }
      }
      if (mismatchedIds.isNotEmpty) {
        for (final id in mismatchedIds) {
          await _db.syncDao
              .markFailed(id, 'missing_business_id', permanent: true);
        }
      }
      if (validPayloads.isEmpty) continue;

      try {
        if (group.action == 'insert' ||
            group.action == 'update' ||
            group.action == 'upsert') {
          if (group.conflictTarget != null) {
            await _supabase
                .from(group.table)
                .upsert(validPayloads, onConflict: group.conflictTarget!);
          } else {
            await _supabase.from(group.table).upsert(validPayloads);
          }
        } else if (group.action == 'delete') {
          // Hard delete only used for tombstones the cloud needs to forget.
          // Soft delete (is_deleted=true) goes through the upsert path above.
          final deleteIds = validPayloads
              .map((p) => p['id'] as String?)
              .whereType<String>()
              .toList();
          if (deleteIds.isNotEmpty) {
            await _supabase
                .from(group.table)
                .delete()
                .inFilter('id', deleteIds);
          }
        }
        await _db.syncDao.markDoneBatch(validIds);
      } catch (e) {
        debugPrint(
          '[SyncService] Batch push failed for ${group.table}:${group.action} '
          '(${validIds.length} items): $e',
        );
        // On batch failure, mark every item failed individually so the
        // existing exponential-backoff per-row state machine still applies.
        for (final id in validIds) {
          await _db.syncDao.markFailed(id, e.toString());
        }
      }
    }

    // If the raw select hit the page limit, more is waiting — drain in the
    // next tick rather than recursing (avoids stack growth on huge backlogs).
    if (rawItems.length == 200) {
      Future.microtask(pushPending);
    }
  }

  /// Pushes one outbox row per call to a Postgres RPC defined in
  /// 0006_domain_rpcs.sql. Used for atomic multi-table actions
  /// (`domain:pos_record_sale`, `domain:pos_inventory_delta`,
  /// `domain:pos_create_product`) where the server applies the entire
  /// business action in a single transaction. On success, applies the
  /// server's authoritative response to the local cache without
  /// re-enqueueing — this and `_restoreTableData` (for pull/realtime) are
  /// the only legitimate paths that write to a synced table without
  /// going through `enqueueUpsert`.
  Future<void> _pushDomainItems(
    List<SyncQueueData> items,
    String sessionBusinessId,
  ) async {
    for (final item in items) {
      await _db.syncDao.markInProgressBatch([item.id]);

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(item.payload) as Map<String, dynamic>;
      } catch (e) {
        await _db.syncDao
            .markFailed(item.id, 'decode_error: $e', permanent: true);
        continue;
      }

      // Tenant guard. The RPC also checks server-side, but failing locally
      // saves a round-trip and avoids a misleading 'tenant_mismatch' RPC
      // error in the Sync Issues UI.
      final payloadBiz = payload['p_business_id'];
      if (item.businessId != sessionBusinessId ||
          payloadBiz is! String ||
          payloadBiz != sessionBusinessId) {
        await _db.syncDao
            .markFailed(item.id, 'missing_business_id', permanent: true);
        continue;
      }

      final rpcName = item.actionType.substring('domain:'.length);
      try {
        final response = await _supabase.rpc(rpcName, params: payload);
        await _applyDomainResponse(rpcName, response);
        await _db.syncDao.markDone(item.id);
      } on PostgrestException catch (e) {
        // P0001 = app-level RAISE EXCEPTION (insufficient_stock,
        // tenant_mismatch, etc.). 23xxx = integrity violations
        // (unique, FK, check). Both are permanent — retrying without a
        // schema/data change cannot succeed.
        final code = e.code ?? '';
        final isPermanent = code == 'P0001' ||
            code.startsWith('23') ||
            code == 'insufficient_privilege' ||
            code == 'invalid_parameter_value';
        debugPrint(
          '[SyncService] Domain RPC $rpcName failed '
          '(code=$code, permanent=$isPermanent): ${e.message}',
        );
        await _db.syncDao
            .markFailed(item.id, 'pg_$code: ${e.message}', permanent: isPermanent);
      } catch (e) {
        debugPrint('[SyncService] Domain RPC $rpcName transient error: $e');
        await _db.syncDao.markFailed(item.id, e.toString());
      }
    }
  }

  /// Reconciles the local cache with the server's authoritative response
  /// from a domain RPC. Bypasses `enqueueUpsert` because the server already
  /// has the truth — pushing it back would be a no-op round trip.
  Future<void> _applyDomainResponse(
    String rpcName,
    dynamic response,
  ) async {
    if (response is! Map) return;
    final map = Map<String, dynamic>.from(response);

    // Inventory cache: pos_record_sale and pos_inventory_delta both return
    // an `inventory_after` array of {product_id, warehouse_id, quantity,
    // last_updated_at}. The Drift `bump_inventory_last_updated_at` trigger
    // only fires when OLD.last_updated_at IS NEW.last_updated_at; we
    // explicitly write the server's value, so the trigger is a no-op and
    // the local row matches the cloud exactly.
    final invAfter = map['inventory_after'];
    if (invAfter is List) {
      for (final raw in invAfter) {
        if (raw is! Map) continue;
        final productId = raw['product_id'] as String?;
        final warehouseId = raw['warehouse_id'] as String?;
        final quantity = raw['quantity'];
        final luaStr = raw['last_updated_at'] as String?;
        if (productId == null || warehouseId == null || quantity is! int) {
          continue;
        }
        final lua = luaStr != null ? DateTime.tryParse(luaStr) : null;
        await (_db.update(_db.inventory)
              ..where((t) =>
                  t.productId.equals(productId) &
                  t.warehouseId.equals(warehouseId)))
            .write(InventoryCompanion(
          quantity: Value(quantity),
          lastUpdatedAt: Value(lua ?? DateTime.now()),
        ));
      }
    }

    // pos_record_sale: bump the local order's last_updated_at to the
    // server's value so the next pull's incremental cursor doesn't re-fetch
    // it on every sync.
    final orderId = map['order_id'] as String?;
    final orderLua = map['order_last_updated_at'] as String?;
    if (orderId != null && orderLua != null) {
      final parsed = DateTime.tryParse(orderLua);
      if (parsed != null) {
        await (_db.update(_db.orders)..where((t) => t.id.equals(orderId)))
            .write(OrdersCompanion(lastUpdatedAt: Value(parsed)));
      }
    }

    // pos_create_product: same for products.
    final productId = map['product_id'] as String?;
    final productLua = map['product_last_updated_at'] as String?;
    if (productId != null && productLua != null) {
      final parsed = DateTime.tryParse(productLua);
      if (parsed != null) {
        await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
            .write(ProductsCompanion(lastUpdatedAt: Value(parsed)));
      }
    }
  }

  /// Synchronously pushes the pending `domain:pos_record_sale` envelope for
  /// the given order. Used by the checkout flow when `isOnline = true` to
  /// surface server-side errors (insufficient_stock, FK/unique violations)
  /// to the user *before* the receipt prints.
  ///
  /// Throws [SaleSyncException] on permanent failure (P0001 / 23xxx).
  /// Returns silently when:
  ///   - the queue row is absent (already pushed by background drain), OR
  ///   - the device is offline (the row stays pending and will drain later), OR
  ///   - the RPC fails with a transient error (queued for backoff retry).
  Future<void> flushSale(String orderId) async {
    if (_supabase.auth.currentUser == null) return;
    if (!isOnline.value) return;
    final sessionBusinessId = _db.currentBusinessId;
    if (sessionBusinessId == null) return;

    final item = await _db.syncDao.findPendingDomainItem(
      'domain:pos_record_sale',
      payloadIdPath: r'$.p_order.id',
      idValue: orderId,
    );
    if (item == null) return;

    await _pushDomainItems([item], sessionBusinessId);

    final updated = await _db.syncDao.getQueueItem(item.id);
    if (updated?.status == 'failed') {
      throw SaleSyncException(
        orderId: orderId,
        errorMessage: updated?.errorMessage ?? 'unknown error',
      );
    }
  }

  /// Orchestrates a two-way sync: push local changes, then pull cloud updates.
  Future<void> syncAll(String businessId) async {
    debugPrint(
      '[SyncService] Starting two-way sync for business $businessId...',
    );
    try {
      await pushPending();

      final prefs = await SharedPreferences.getInstance();
      // Per-business key: a wiped DB or a device that has switched businesses
      // must not inherit the timestamp from a different tenant, otherwise
      // incremental pulls skip rows that haven't been touched in the cloud
      // since the unrelated last sync.
      final key = 'last_sync_timestamp::$businessId';
      final lastSyncStr = prefs.getString(key);
      DateTime? since;
      if (lastSyncStr != null) {
        since = DateTime.tryParse(lastSyncStr);
      }

      await pullInitialData(businessId, since: since);

      await prefs.setString(key, DateTime.now().toUtc().toIso8601String());
      debugPrint('[SyncService] Two-way sync completed successfully.');
    } catch (e) {
      debugPrint('[SyncService] Sync failed: $e');
      rethrow;
    }
  }

  /// Tables fed into `_restoreTableData` after a pull, in FK-safe order.
  /// `crates` removed — cloud schema has only `crate_groups`.
  static const _pullOrder = [
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
    'purchases',
    'purchase_items',
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
    'manufacturer_crate_balances',
    'crate_ledger',
    'system_config',
    'price_lists',
    'payment_transactions',
    'sessions',
    'settings',
  ];

  /// Pulls data for the current business from Supabase and populates the local DB.
  /// If [since] is provided, performs an incremental pull.
  ///
  /// Fast path: a single `pos_pull_snapshot` RPC returns every table's rows
  /// in one round-trip. Falls back to the per-table PostgREST path if the
  /// RPC isn't deployed yet (the migration in 0005_sync_rpcs.sql may not be
  /// applied to every environment).
  Future<void> pullInitialData(String businessId, {DateTime? since}) async {
    // Force a full sync if the business is not found locally.
    final localBusiness = await (_db.select(
      _db.businesses,
    )..where((t) => t.id.equals(businessId))).getSingleOrNull();
    if (localBusiness == null) {
      debugPrint(
        '[SyncService] Business $businessId not found in local database. Forcing full sync.',
      );
      since = null;
    }

    debugPrint(
      '[SyncService] Pulling data for business $businessId (since: ${since?.toIso8601String() ?? "beginning"})...',
    );

    Map<String, List<dynamic>>? snapshot;
    try {
      final result = await _supabase.rpc(
        'pos_pull_snapshot',
        params: {
          'p_business_id': businessId,
          'p_since': since?.toIso8601String(),
        },
      ).timeout(const Duration(seconds: 30));
      if (result is Map) {
        snapshot = <String, List<dynamic>>{
          for (final entry in result.entries)
            if (entry.value is List)
              entry.key.toString(): List<dynamic>.from(entry.value as List),
        };
        debugPrint(
          '[SyncService] Snapshot RPC returned '
          '${snapshot.values.fold<int>(0, (a, l) => a + l.length)} rows '
          'across ${snapshot.length} tables.',
        );
      }
    } catch (e) {
      debugPrint(
        '[SyncService] Snapshot RPC unavailable, falling back to per-table fetch: $e',
      );
    }

    snapshot ??= await _pullViaPostgRest(businessId, since);

    for (final table in _pullOrder) {
      final data = snapshot[table];
      if (data != null && data.isNotEmpty) {
        debugPrint('[SyncService] Syncing $table: ${data.length} rows');
        await _restoreTableData(table, data);
      }
    }
  }

  /// Per-table parallel fetch — the original pull path. Used as a fallback
  /// when the snapshot RPC is unavailable.
  Future<Map<String, List<dynamic>>> _pullViaPostgRest(
    String businessId,
    DateTime? since,
  ) async {
    final fetchResults = await Future.wait(
      _pullOrder.map((table) async {
        try {
          final isGlobal = table == 'system_config';
          var query = _supabase.from(table).select();

          if (!isGlobal) {
            // The cloud `businesses` table has no `business_id` column — its `id`
            // IS the business id. All other tables filter by `business_id`.
            final filterColumn = table == 'businesses' ? 'id' : 'business_id';
            query = query.eq(filterColumn, businessId);
          }

          // The `businesses` row is the FK target for almost everything
          // local. Always fetch it unconditionally so a stale `since` can't
          // produce a sync where children try to insert against a missing
          // parent.
          if (since != null && table != 'businesses') {
            query = query.gt('last_updated_at', since.toIso8601String());
          }

          final List<dynamic> data = await query.timeout(
            const Duration(seconds: 15),
          );
          return MapEntry(table, data);
        } catch (e) {
          debugPrint('[SyncService] Error pulling table $table: $e');
          return MapEntry(table, const <dynamic>[]);
        }
      }),
    );
    return Map.fromEntries(fetchResults);
  }

  /// Subscribes to real-time changes from Supabase for this business.
  void startRealtimeSync(String businessId) {
    if (_realtimeChannel != null) return;

    debugPrint(
      '[SyncService] Starting real-time sync for business $businessId',
    );

    // Wildcard subscription for all tables with a `business_id` column.
    // The `businesses` table has no `business_id` and is handled separately.
    // Per-table refactor deferred — wrap in try/catch so a single bad table
    // doesn't kill the whole channel.
    try {
      _realtimeChannel =
          _supabase
              .channel('public:*')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'business_id',
                  value: businessId,
                ),
                callback: (payload) async {
                  debugPrint(
                    '[SyncService] Realtime Event: ${payload.eventType} on ${payload.table}',
                  );

                  final table = payload.table;
                  final newRecord = payload.newRecord;

                  if (newRecord.isNotEmpty) {
                    await _restoreTableData(table, [newRecord]);
                    // Single-active-device sign-in: when our own session row
                    // gets revoked by another device's fresh sign-in, ask
                    // AuthService to fullLogout this device.
                    if (table == 'sessions' &&
                        newRecord['revoked_at'] != null &&
                        newRecord['id'] == currentSessionIdResolver?.call()) {
                      onCurrentSessionRevoked?.call();
                    }
                  } else if (payload.eventType == PostgresChangeEvent.delete &&
                      payload.oldRecord.isNotEmpty) {
                    final id = payload.oldRecord['id'];
                    if (id != null) {
                      // For now, soft deletes are handled as updates.
                    }
                  }
                },
              )
            ..subscribe();
    } catch (e) {
      debugPrint('[SyncService] Wildcard realtime subscribe failed: $e');
    }

    // Separate channel for `businesses` filtered by `id` (no business_id column).
    try {
      _businessesChannel =
          _supabase
              .channel('public:businesses')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'businesses',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'id',
                  value: businessId,
                ),
                callback: (payload) async {
                  debugPrint(
                    '[SyncService] Realtime Event: ${payload.eventType} on businesses',
                  );
                  final newRecord = payload.newRecord;
                  if (newRecord.isNotEmpty) {
                    await _restoreTableData('businesses', [newRecord]);
                  }
                },
              )
            ..subscribe();
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
      // One-shot recovery: re-enqueue rows that were inserted before
      // their owning DAO method was wired to call `enqueueUpsert` (i.e.
      // pre-redesign leaks). Drift's NOT-NULL DEFAULT on `last_updated_at`
      // means new writes are always tagged, so there's nothing to find on
      // the second-and-beyond app launches. The flag prevents this scan
      // from running per-launch.
      final prefs = await SharedPreferences.getInstance();
      const oneShotKey = 'global_unsynced_backfill_v2_2026Q2';
      if (prefs.getBool(oneShotKey) != true) {
        await _backfillAllUnsyncedTables();
        await prefs.setBool(oneShotKey, true);
      }

      if (_supabase.auth.currentUser != null) {
        await _db.syncDao.clearFailureBackoff();
      }

      var lastCount = 0;
      _autoPushSub = _db.syncDao.watchPendingCount().listen((count) {
        final prev = lastCount;
        lastCount = count;
        if (count == 0) return;
        // 0→N transition: skip the coalesce window so the first write of
        // an idle period goes up immediately. Subsequent enqueues during
        // an in-flight push are still coalesced into the next cycle.
        if (prev == 0) {
          _schedulePushImmediate();
        } else {
          _scheduleDebouncedPush();
        }
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

      _connectivitySub ??= Connectivity().onConnectivityChanged.listen(
        _handleConnectivityTransition,
      );
    } finally {
      _autoPushStarting = false;
    }
  }

  /// Coalesce-window for bursty writes. Long enough to merge the 5–8
  /// enqueues of a single createOrder transaction (they happen within
  /// ~10ms of each other inside one Drift txn) but short enough that an
  /// isolated write doesn't feel laggy. Was 500ms — measured to add half a
  /// second to every send.
  static const _pushDebounce = Duration(milliseconds: 60);

  void _scheduleDebouncedPush() {
    _autoPushDebounce?.cancel();
    _autoPushDebounce = Timer(_pushDebounce, _runPushOnce);
  }

  /// Bypasses the debounce window. Used when the queue transitions 0→N: the
  /// first write should not wait the coalesce window before going up.
  void _schedulePushImmediate() {
    _autoPushDebounce?.cancel();
    Future.microtask(_runPushOnce);
  }

  Future<void> _runPushOnce() async {
    if (_pushing) return;
    _pushing = true;
    try {
      await pushPending();
    } catch (e) {
      debugPrint('[SyncService] auto-push failed: $e');
    } finally {
      _pushing = false;
    }
  }

  /// Enqueues an upsert for any warehouse that has never been synced
  /// (`lastUpdatedAt IS NULL`). Onboarding originally inserted warehouses
  /// without going through the sync queue, leaving customer/product FKs
  /// dangling in the cloud. Idempotent: marking `lastUpdatedAt` after
  /// enqueueing prevents re-queueing on subsequent startups.
  Future<void> _backfillUnsyncedWarehouses() async {
    try {
      final whs = await (_db.select(
        _db.warehouses,
      )..where((t) => t.lastUpdatedAt.isNull())).get();
      if (whs.isEmpty) return;

      final now = DateTime.now();
      var enqueued = 0;
      for (final w in whs) {
        final businessId = w.businessId;
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
        );
        await (_db.update(_db.warehouses)..where((t) => t.id.equals(w.id)))
            .write(WarehousesCompanion(lastUpdatedAt: Value(now)));
        enqueued++;
      }

      if (enqueued > 0) {
        debugPrint('[SyncService] Warehouse backfill: enqueued=$enqueued');
      }
    } catch (e) {
      debugPrint('[SyncService] Warehouse backfill failed: $e');
    }
  }

  Future<void> _handleConnectivityTransition(
    List<ConnectivityResult> results,
  ) async {
    final hasNetwork =
        !(results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none));
    isOnline.value = hasNetwork;
    if (hasNetwork) {
      debugPrint(
        '[SyncService] Usable network connected, flushing and pulling...',
      );
      await _db.syncDao.clearFailureBackoff();
      _scheduleDebouncedPush();

      final businessId = _db.businessIdResolver.call();
      if (businessId != null) {
        unawaited(() async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final key = 'last_sync_timestamp::$businessId';
            final lastSyncStr = prefs.getString(key);
            DateTime? since;
            if (lastSyncStr != null) {
              since = DateTime.tryParse(lastSyncStr);
            }
            await pullInitialData(businessId, since: since);
          } catch (e) {
            debugPrint('[SyncService] Connectivity pull failed: $e');
          }
        }());
      }
    }
  }

  Future<void> _backfillTable<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String tableName,
    String Function(D) getId,
  ) async {
    try {
      final column = table.columnsByName['last_updated_at'];
      if (column == null) return;

      final query = _db.select(table)
        ..where((t) {
          final lastUpdatedField =
              table.columnsByName['last_updated_at'] as Expression<DateTime>;
          return lastUpdatedField.isNull();
        });
      final rows = await query.get();
      if (rows.isEmpty) return;

      final now = DateTime.now();
      for (final row in rows) {
        final id = getId(row);
        await _db.syncDao.enqueueUpsert(tableName, row as Insertable);

        final updateQuery = _db.update(table)
          ..where((t) {
            final idField = table.columnsByName['id'] as Expression<String>;
            return idField.equals(id);
          });

        await updateQuery.write(
          RawValuesInsertable({'last_updated_at': Variable(now)}),
        );
      }
      debugPrint('[SyncService] Backfilled ${rows.length} rows for $tableName');
    } catch (e) {
      debugPrint('[SyncService] Backfill for $tableName failed: $e');
    }
  }

  /// One-shot recovery for categories created before the
  /// CatalogDao.insertCategory wiring landed. Earlier builds wrote default
  /// categories straight into Drift without ever enqueueing them, so cloud
  /// `categories` stayed empty and every product/inventory/stock_* push
  /// FK-failed against it. Re-enqueue every local category once; the server's
  /// ON CONFLICT (id) DO UPDATE makes this idempotent. Gated by a one-shot
  /// SharedPreferences flag so subsequent launches don't re-flood the queue.
  Future<void> _backfillUnsyncedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const flagKey = 'categories_backfill_v1';
      if (prefs.getBool(flagKey) == true) return;

      final cats = await _db.select(_db.categories).get();
      if (cats.isEmpty) {
        await prefs.setBool(flagKey, true);
        return;
      }

      var enqueued = 0;
      for (final c in cats) {
        await _db.syncDao.enqueueUpsert('categories', c);
        enqueued++;
      }
      await prefs.setBool(flagKey, true);
      if (enqueued > 0) {
        debugPrint('[SyncService] Categories backfill: enqueued=$enqueued');
      }
    } catch (e) {
      debugPrint('[SyncService] Categories backfill failed: $e');
    }
  }

  Future<void> _backfillAllUnsyncedTables() async {
    try {
      await _backfillUnsyncedWarehouses();
      await _backfillUnsyncedCategories();
      await _backfillTable(_db.products, 'products', (row) => row.id);
      await _backfillTable(_db.categories, 'categories', (row) => row.id);
      await _backfillTable(_db.customers, 'customers', (row) => row.id);
      await _backfillTable(_db.suppliers, 'suppliers', (row) => row.id);
      await _backfillTable(_db.orders, 'orders', (row) => row.id);
      await _backfillTable(_db.orderItems, 'order_items', (row) => row.id);
      await _backfillTable(_db.expenses, 'expenses', (row) => row.id);
      await _backfillTable(
        _db.expenseCategories,
        'expense_categories',
        (row) => row.id,
      );
      await _backfillTable(
        _db.customerCrateBalances,
        'customer_crate_balances',
        (row) => row.id,
      );
      await _backfillTable(
        _db.deliveryReceipts,
        'delivery_receipts',
        (row) => row.id,
      );
      await _backfillTable(_db.drivers, 'drivers', (row) => row.id);
      await _backfillTable(
        _db.stockTransfers,
        'stock_transfers',
        (row) => row.id,
      );
      await _backfillTable(
        _db.stockAdjustments,
        'stock_adjustments',
        (row) => row.id,
      );
      await _backfillTable(
        _db.customerWallets,
        'customer_wallets',
        (row) => row.id,
      );
      await _backfillTable(
        _db.walletTransactions,
        'wallet_transactions',
        (row) => row.id,
      );
      await _backfillTable(_db.savedCarts, 'saved_carts', (row) => row.id);
      await _backfillTable(
        _db.pendingCrateReturns,
        'pending_crate_returns',
        (row) => row.id,
      );
    } catch (e) {
      debugPrint('[SyncService] General backfill failed: $e');
    }
  }

  void stopAutoPush() {
    _autoPushDebounce?.cancel();
    _autoPushDebounce = null;
    _autoPushSub?.cancel();
    _autoPushSub = null;
    _authStateSub?.cancel();
    _authStateSub = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Cloud `jsonb` columns arrive as Map/List, but Drift stores them as TEXT.
  /// Stringify so DataClass.fromJson<String?> can cast without throwing.
  static dynamic _stringifyJsonb(dynamic v) {
    if (v is Map || v is List) return jsonEncode(v);
    return v;
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
    final rows = data
        .map((e) => _snakeToCamel(e as Map<String, dynamic>))
        .toList();

    await _db.transaction(() async {
      switch (table) {
        case 'businesses':
          for (var r in rows) {
            // Cloud `businesses` lacks `timezone` (local-only column with
            // default 'UTC'). Without this, fromJson casts null → String and
            // throws on every restore.
            r.putIfAbsent('timezone', () => 'UTC');
            r.putIfAbsent('onboardingComplete', () => false);
            await _db
                .into(_db.businesses)
                .insertOnConflictUpdate(BusinessData.fromJson(r));
          }
          break;
        case 'warehouses':
          for (var r in rows) {
            await _db
                .into(_db.warehouses)
                .insertOnConflictUpdate(WarehouseData.fromJson(r));
          }
          break;
        case 'profiles':
          // No-op: cloud `profiles` has no email column, so multi-user backfill
          // here is unreliable. The current user's local row is upserted via
          // AuthService.upsertLocalUserFromProfile() during the auth flow.
          debugPrint(
            '[SyncService] Skipping bulk profiles restore (${rows.length} rows) — handled by auth flow.',
          );
          break;
        case 'products':
          for (var r in rows) {
            await _db
                .into(_db.products)
                .insertOnConflictUpdate(ProductData.fromJson(r));
          }
          break;
        case 'crate_groups':
          for (var r in rows) {
            await _db
                .into(_db.crateGroups)
                .insertOnConflictUpdate(CrateGroupData.fromJson(r));
          }
          break;
        case 'manufacturers':
          for (var r in rows) {
            await _db
                .into(_db.manufacturers)
                .insertOnConflictUpdate(ManufacturerData.fromJson(r));
          }
          break;
        case 'categories':
          for (var r in rows) {
            await _db
                .into(_db.categories)
                .insertOnConflictUpdate(CategoryData.fromJson(r));
          }
          break;
        case 'inventory':
          for (var r in rows) {
            await _db
                .into(_db.inventory)
                .insertOnConflictUpdate(InventoryData.fromJson(r));
          }
          break;
        case 'customers':
          for (var r in rows) {
            await _db
                .into(_db.customers)
                .insertOnConflictUpdate(CustomerData.fromJson(r));
          }
          break;
        case 'suppliers':
          for (var r in rows) {
            await _db
                .into(_db.suppliers)
                .insertOnConflictUpdate(SupplierData.fromJson(r));
          }
          break;
        case 'orders':
          for (var r in rows) {
            await _db
                .into(_db.orders)
                .insertOnConflictUpdate(OrderData.fromJson(r));
          }
          break;
        case 'order_items':
          for (var r in rows) {
            r['priceSnapshot'] = _stringifyJsonb(r['priceSnapshot']);
            await _db
                .into(_db.orderItems)
                .insertOnConflictUpdate(OrderItemData.fromJson(r));
          }
          break;
        case 'expenses':
          for (var r in rows) {
            await _db
                .into(_db.expenses)
                .insertOnConflictUpdate(ExpenseData.fromJson(r));
          }
          break;
        case 'expense_categories':
          for (var r in rows) {
            await _db
                .into(_db.expenseCategories)
                .insertOnConflictUpdate(ExpenseCategoryData.fromJson(r));
          }
          break;
        case 'manufacturer_crate_balances':
          for (var r in rows) {
            await _db
                .into(_db.manufacturerCrateBalances)
                .insertOnConflictUpdate(ManufacturerCrateBalance.fromJson(r));
          }
          break;
        case 'crate_ledger':
          for (var r in rows) {
            await _db
                .into(_db.crateLedger)
                .insertOnConflictUpdate(CrateLedgerData.fromJson(r));
          }
          break;
        case 'system_config':
          for (var r in rows) {
            r['value'] = _stringifyJsonb(r['value']);
            await _db
                .into(_db.systemConfig)
                .insertOnConflictUpdate(SystemConfigData.fromJson(r));
          }
          break;
        case 'purchases':
          for (var r in rows) {
            await _db
                .into(_db.purchases)
                .insertOnConflictUpdate(DeliveryData.fromJson(r));
          }
          break;
        case 'purchase_items':
          for (var r in rows) {
            await _db
                .into(_db.purchaseItems)
                .insertOnConflictUpdate(PurchaseItemData.fromJson(r));
          }
          break;
        case 'customer_crate_balances':
          for (var r in rows) {
            await _db
                .into(_db.customerCrateBalances)
                .insertOnConflictUpdate(CustomerCrateBalance.fromJson(r));
          }
          break;
        case 'delivery_receipts':
          for (var r in rows) {
            await _db
                .into(_db.deliveryReceipts)
                .insertOnConflictUpdate(DeliveryReceiptData.fromJson(r));
          }
          break;
        case 'drivers':
          for (var r in rows) {
            await _db
                .into(_db.drivers)
                .insertOnConflictUpdate(DriverData.fromJson(r));
          }
          break;
        case 'price_lists':
          for (var r in rows) {
            await _db
                .into(_db.priceLists)
                .insertOnConflictUpdate(PriceListData.fromJson(r));
          }
          break;
        case 'payment_transactions':
          for (var r in rows) {
            await _db
                .into(_db.paymentTransactions)
                .insertOnConflictUpdate(PaymentTransactionData.fromJson(r));
          }
          break;
        case 'stock_transfers':
          for (var r in rows) {
            await _db
                .into(_db.stockTransfers)
                .insertOnConflictUpdate(StockTransferData.fromJson(r));
          }
          break;
        case 'stock_adjustments':
          for (var r in rows) {
            await _db
                .into(_db.stockAdjustments)
                .insertOnConflictUpdate(StockAdjustmentData.fromJson(r));
          }
          break;
        case 'activity_logs':
          for (var r in rows) {
            await _db
                .into(_db.activityLogs)
                .insertOnConflictUpdate(ActivityLogData.fromJson(r));
          }
          break;
        case 'notifications':
          for (var r in rows) {
            await _db
                .into(_db.notifications)
                .insertOnConflictUpdate(NotificationData.fromJson(r));
          }
          break;
        case 'settings':
          for (var r in rows) {
            await _db
                .into(_db.settings)
                .insertOnConflictUpdate(SettingData.fromJson(r));
          }
          break;
        case 'sessions':
          for (var r in rows) {
            await _db
                .into(_db.sessions)
                .insertOnConflictUpdate(SessionData.fromJson(r));
          }
          break;
        case 'stock_transactions':
          for (var r in rows) {
            await _db
                .into(_db.stockTransactions)
                .insertOnConflictUpdate(StockTransactionData.fromJson(r));
          }
          break;
        case 'customer_wallets':
          for (var r in rows) {
            await _db
                .into(_db.customerWallets)
                .insertOnConflictUpdate(CustomerWalletData.fromJson(r));
          }
          break;
        case 'wallet_transactions':
          for (var r in rows) {
            await _db
                .into(_db.walletTransactions)
                .insertOnConflictUpdate(WalletTransactionData.fromJson(r));
          }
          break;
        case 'saved_carts':
          for (var r in rows) {
            r['cartData'] = _stringifyJsonb(r['cartData']);
            await _db
                .into(_db.savedCarts)
                .insertOnConflictUpdate(SavedCartData.fromJson(r));
          }
          break;
        case 'pending_crate_returns':
          for (var r in rows) {
            await _db
                .into(_db.pendingCrateReturns)
                .insertOnConflictUpdate(PendingCrateReturnData.fromJson(r));
          }
          break;
        case 'invites':
          for (var r in rows) {
            await _db
                .into(_db.invites)
                .insertOnConflictUpdate(InviteData.fromJson(r));
          }
          break;
        default:
          debugPrint('[SyncService] Restore logic not implemented for $table');
      }
    });
  }
}

/// Group key for batched pushes: items sharing (table, action, conflictTarget)
/// can be sent in a single Supabase array-upsert / array-delete call.
class _PushGroup {
  final String table;
  final String action;
  final String? conflictTarget;
  const _PushGroup({
    required this.table,
    required this.action,
    this.conflictTarget,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PushGroup &&
          table == other.table &&
          action == other.action &&
          conflictTarget == other.conflictTarget;

  @override
  int get hashCode => Object.hash(table, action, conflictTarget);
}
