import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

void main() {
  late AppDatabase db;
  late String businessId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    businessId = UuidV7.generate();
    db.businessIdResolver = () => businessId;
    await db.into(db.businesses).insert(BusinessesCompanion.insert(
          id: Value(businessId),
          name: 'Test Biz',
        ));
  });

  tearDown(() => db.close());

  test('addCustomer creates both customer + wallet rows', () async {
    final customerId = await db.customersDao.addCustomer(
      CustomersCompanion.insert(businessId: businessId, name: 'Alice'),
    );

    final customers = await db.select(db.customers).get();
    expect(customers, hasLength(1));
    expect(customers.first.id, equals(customerId));

    final wallets = await db.select(db.customerWallets).get();
    expect(wallets, hasLength(1));
    expect(wallets.first.customerId, equals(customerId));
    expect(wallets.first.businessId, equals(businessId));
  });

  test('addCustomer rolls back when wallet insert fails', () async {
    // Trigger a failure by inserting a wallet row with the (yet-to-exist)
    // customerId beforehand — the UNIQUE(business_id, customer_id) constraint
    // on CustomerWallets forces the second insert (inside addCustomer) to
    // throw, exercising the transaction rollback.
    //
    // We simulate that by patching the customer companion id and pre-inserting
    // a colliding wallet row. Since addCustomer generates its own UUIDs we
    // can't predict them — instead, register a custom statement that always
    // fails during the wallet insert by dropping CustomerWallets first.
    await db.customStatement('DROP TABLE customer_wallets');

    Object? caught;
    try {
      await db.customersDao.addCustomer(
        CustomersCompanion.insert(businessId: businessId, name: 'Bob'),
      );
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);

    final customers = await db.select(db.customers).get();
    expect(
      customers,
      isEmpty,
      reason: 'transaction must roll back the customer insert when wallet '
          'insert fails',
    );
  });
}
