import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';

import '../../helpers/dispatch_test_utils.dart';

void main() {
  late AppDatabase db;
  late String businessId;

  setUp(() async {
    final boot = await bootstrapTestDb();
    db = boot.db;
    businessId = boot.businessId;
  });

  tearDown(() => db.close());

  group('CustomersDao.addCustomer dispatch', () {
    test(
      'flag OFF: enqueues two upsert rows (customers + customer_wallets)',
      () async {
        await setFlag(db, 'feature.domain_rpcs_v2.create_customer', on: false);

        final id = await db.customersDao.addCustomer(
          CustomersCompanion.insert(
            businessId: businessId,
            name: 'Legacy Path Lou',
          ),
        );

        // Local rows present.
        final cust =
            await (db.select(db.customers)..where((t) => t.id.equals(id))).get();
        expect(cust, hasLength(1), reason: 'customer row inserted locally');
        final wal = await (db.select(db.customerWallets)
              ..where((t) => t.customerId.equals(id)))
            .get();
        expect(wal, hasLength(1), reason: 'wallet row inserted locally');

        // Outbox: two upsert rows, no domain envelope.
        final pending = await getPendingQueue(db);
        final actionTypes = pending.map((r) => r.actionType).toList()..sort();
        expect(actionTypes, ['customer_wallets:upsert', 'customers:upsert']);
        expect(
          pending.where((r) => r.actionType.startsWith('domain:')),
          isEmpty,
          reason: 'no domain envelope when flag is off',
        );
      },
    );

    test(
      'flag ON: enqueues one domain:pos_create_customer envelope, no upserts',
      () async {
        await setFlag(db, 'feature.domain_rpcs_v2.create_customer', on: true);

        final id = await db.customersDao.addCustomer(
          CustomersCompanion.insert(
            businessId: businessId,
            name: 'V2 Path Vic',
            phone: const Value('+2348012345678'),
            address: const Value('1 Test Street'),
          ),
        );

        // Local rows still present (UI updates immediately).
        final cust =
            await (db.select(db.customers)..where((t) => t.id.equals(id))).get();
        expect(cust, hasLength(1));

        // Outbox: one domain row.
        final pending = await getPendingQueue(db);
        expect(pending, hasLength(1), reason: 'exactly one envelope');
        expect(pending.first.actionType, 'domain:pos_create_customer');

        // Payload shape.
        final payload = decodePayload(pending.first);
        expect(payload['p_business_id'], businessId);
        expect(payload['p_customer_id'], id);
        expect(payload['p_wallet_id'], isA<String>());
        expect(payload['p_name'], 'V2 Path Vic');
        expect(payload['p_phone'], '+2348012345678');
        expect(payload['p_address'], '1 Test Street');

        // Optional fields the caller didn't set must be absent — proves the
        // dispatch isn't padding the envelope with unsolicited keys.
        expect(payload.containsKey('p_email'), isFalse);
        expect(payload.containsKey('p_google_maps_location'), isFalse);
      },
    );

    test('flag ON: customer_wallet id in payload matches the local wallet row',
        () async {
      await setFlag(db, 'feature.domain_rpcs_v2.create_customer', on: true);

      final id = await db.customersDao.addCustomer(
        CustomersCompanion.insert(businessId: businessId, name: 'Walter'),
      );

      final wallets = await (db.select(db.customerWallets)
            ..where((t) => t.customerId.equals(id)))
          .get();
      expect(wallets, hasLength(1));

      final pending = await getPendingQueue(db);
      final payload = decodePayload(pending.first);
      expect(
        payload['p_wallet_id'],
        wallets.first.id,
        reason:
            'envelope must reference the same wallet row that was written '
            'locally, so the server-side ON CONFLICT (id) DO NOTHING reads '
            'as a true idempotent retry on replay',
      );
    });
  });
}
