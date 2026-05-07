import 'package:drift/drift.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

class CrateReturnApprovalService {
  final AppDatabase db;

  CrateReturnApprovalService(this.db);

  Future<List<PendingCrateReturnData>> listPending(String businessId) {
    return (db.select(db.pendingCrateReturns)
          ..where((t) =>
              t.businessId.equals(businessId) & t.status.equals('pending')))
        .get();
  }

  Future<void> approve(String returnId, String approvedBy) async {
    final pending = await db.pendingCrateReturnsDao.getById(returnId);
    if (pending == null) throw Exception('Pending return not found');
    if (pending.status != 'pending') {
      throw Exception('Return is already ${pending.status}');
    }

    await db.transaction(() async {
      // 1. Update pending_crate_returns row (status + approval metadata in
      //    one combined Companion so a single enqueue carries the whole
      //    transition to the cloud).
      final now = DateTime.now();
      final pcrComp = PendingCrateReturnsCompanion(
        id: Value(returnId),
        status: const Value('approved'),
        approvedBy: Value(approvedBy),
        approvedAt: Value(now),
        lastUpdatedAt: Value(now),
      );
      await (db.update(db.pendingCrateReturns)
            ..where((t) => t.id.equals(returnId)))
          .write(pcrComp);
      await db.syncDao.enqueueUpsert('pending_crate_returns', pcrComp);

      // 2. Append crate_ledger row (append-only).
      // quantityDelta must be negative (customer returning crates reduces their balance)
      final delta = -pending.quantity;

      final ledgerComp = CrateLedgerCompanion.insert(
        id: Value(UuidV7.generate()),
        businessId: pending.businessId,
        customerId: Value(pending.customerId),
        manufacturerId:
            const Value.absent(), // CHECK constraint requires exactly one
        crateGroupId: pending.crateGroupId,
        quantityDelta: delta,
        movementType: 'returned',
        referenceReturnId: Value(returnId),
        performedBy: Value(approvedBy),
        lastUpdatedAt: Value(now),
      );
      await db.into(db.crateLedger).insert(ledgerComp);
      await db.syncDao.enqueueUpsert('crate_ledger', ledgerComp);

      // 3. Update customer_crate_balances cache via upsert + enqueue the
      //    resulting row so the cloud cache converges.
      await db.customStatement(
        'INSERT INTO customer_crate_balances (id, business_id, customer_id, crate_group_id, balance) '
        'VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(business_id, customer_id, crate_group_id) DO UPDATE SET '
        'balance = balance + excluded.balance, last_updated_at = CURRENT_TIMESTAMP',
        [
          UuidV7.generate(),
          pending.businessId,
          pending.customerId,
          pending.crateGroupId,
          delta
        ],
      );
      final balRow = await (db.select(db.customerCrateBalances)
            ..where((t) =>
                t.businessId.equals(pending.businessId) &
                t.customerId.equals(pending.customerId) &
                t.crateGroupId.equals(pending.crateGroupId)))
          .getSingle();
      await db.syncDao.enqueueUpsert('customer_crate_balances', balRow);
    });
  }

  Future<void> reject(
    String returnId,
    String approvedBy,
    String rejectionReason,
  ) async {
    final pending = await db.pendingCrateReturnsDao.getById(returnId);
    if (pending == null) throw Exception('Pending return not found');
    if (pending.status != 'pending') {
      throw Exception('Return is already ${pending.status}');
    }

    await db.transaction(() async {
      final now = DateTime.now();
      final pcrComp = PendingCrateReturnsCompanion(
        id: Value(returnId),
        status: const Value('rejected'),
        approvedBy: Value(approvedBy),
        approvedAt: Value(now),
        rejectionReason: Value(rejectionReason),
        lastUpdatedAt: Value(now),
      );
      await (db.update(db.pendingCrateReturns)
            ..where((t) => t.id.equals(returnId)))
          .write(pcrComp);
      await db.syncDao.enqueueUpsert('pending_crate_returns', pcrComp);
    });
  }
}
