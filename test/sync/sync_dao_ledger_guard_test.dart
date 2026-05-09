import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

import '../helpers/dispatch_test_utils.dart';

/// Locks in the §4.3 invariant: enqueueDelete must reject append-only
/// ledger tables. The cloud's forbid_delete trigger would raise P0001
/// on these, leaving the row permanently failed in the outbox; better
/// to fail fast at the local API boundary.
void main() {
  group('SyncDao.enqueueDelete ledger guard', () {
    for (final ledger in const [
      'wallet_transactions',
      'stock_transactions',
      'payment_transactions',
      'activity_logs',
      'crate_ledger',
    ]) {
      test('rejects $ledger', () async {
        final boot = await bootstrapTestDb();
        try {
          expect(
            () => boot.db.syncDao.enqueueDelete(ledger, UuidV7.generate()),
            throwsA(isA<StateError>()),
          );
        } finally {
          await boot.db.close();
        }
      });
    }

    test('still allows non-ledger tables', () async {
      final boot = await bootstrapTestDb();
      try {
        // Should not throw — products is soft-deletable.
        await boot.db.syncDao.enqueueDelete('products', UuidV7.generate());
      } finally {
        await boot.db.close();
      }
    });
  });
}
