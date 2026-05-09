import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';

import '../../helpers/dispatch_test_utils.dart';

/// §4.6 / §5: saved_carts is in _syncedTenantTables but the original
/// DAO bypassed SyncDao. These tests lock in the wired-through path.
void main() {
  late AppDatabase db;
  late String businessId;

  setUp(() async {
    final boot = await bootstrapTestDb();
    db = boot.db;
    businessId = boot.businessId;
  });

  tearDown(() => db.close());

  group('OrdersDao saved_carts dispatch', () {
    test('saveCart enqueues a saved_carts:upsert row', () async {
      final cartId = await db.ordersDao.saveCart(
        SavedCartsCompanion.insert(
          businessId: businessId,
          name: 'Test Cart',
          cartData: '{"items": []}',
        ),
      );

      expect(await db.select(db.savedCarts).get(), hasLength(1));

      final pending = await getPendingQueue(db);
      expect(pending, hasLength(1));
      expect(pending.first.actionType, 'saved_carts:upsert');

      final payload = decodePayload(pending.first);
      expect(payload['id'], cartId);
      expect(payload['business_id'], businessId);
    });

    test('deleteSavedCart enqueues a saved_carts:delete row', () async {
      final cartId = await db.ordersDao.saveCart(
        SavedCartsCompanion.insert(
          businessId: businessId,
          name: 'Test Cart',
          cartData: '{"items": []}',
        ),
      );
      // Drain the upsert from saveCart so we only see the delete.
      await db.delete(db.syncQueue).go();

      await db.ordersDao.deleteSavedCart(cartId);

      expect(await db.select(db.savedCarts).get(), isEmpty);

      final pending = await getPendingQueue(db);
      expect(pending, hasLength(1));
      expect(pending.first.actionType, 'saved_carts:delete');
      final payload = decodePayload(pending.first);
      expect(payload['id'], cartId);
      expect(payload['is_deleted'], true);
    });

    test('saveCart followed by deleteSavedCart coalesces correctly',
        () async {
      // Saving and immediately deleting in the same offline session must
      // not leave the upsert + delete both pending — the delete should
      // supersede the upsert (existing enqueueDelete behaviour for
      // tombstoning).
      final cartId = await db.ordersDao.saveCart(
        SavedCartsCompanion.insert(
          businessId: businessId,
          name: 'Test Cart',
          cartData: '{"items": []}',
        ),
      );
      await db.ordersDao.deleteSavedCart(cartId);

      final pending = await getPendingQueue(db);
      // The upsert should have been swept to 'completed'/'isSynced=true'
      // by enqueueDelete's supersede logic; only the delete remains
      // pending.
      expect(pending, hasLength(1));
      expect(pending.first.actionType, 'saved_carts:delete');
    });
  });
}
