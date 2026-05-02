import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

void main() {
  late AppDatabase db;
  late String businessId;
  late String customerId;
  late String walletId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    businessId = UuidV7.generate();
    db.businessIdResolver = () => businessId;
    await db.into(db.businesses).insert(BusinessesCompanion.insert(
          id: Value(businessId),
          name: 'Test Biz',
        ));
    customerId = await db.customersDao.addCustomer(
      CustomersCompanion.insert(businessId: businessId, name: 'Alice'),
    );
    final wallet = await (db.select(db.customerWallets)
          ..where((t) => t.customerId.equals(customerId)))
        .getSingle();
    walletId = wallet.id;
  });

  tearDown(() => db.close());

  Future<void> insertTx({
    required int signedAmountKobo,
    required String type,
    required String referenceType,
    DateTime? voidedAt,
  }) async {
    await db.into(db.walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            businessId: businessId,
            walletId: walletId,
            customerId: customerId,
            type: type,
            amountKobo: signedAmountKobo.abs(),
            signedAmountKobo: signedAmountKobo,
            referenceType: referenceType,
            voidedAt: Value(voidedAt),
          ),
        );
  }

  test('getWalletBalanceKobo sums signed amounts (compensating-entry voids)',
      () async {
    await insertTx(
        signedAmountKobo: 5000, type: 'credit', referenceType: 'topup_cash');
    await insertTx(
        signedAmountKobo: -2000,
        type: 'debit',
        referenceType: 'order_payment');
    // A reward credit that was later voided via a compensating debit. Per
    // PR 4d's "compensating entry" void approach, both rows remain in the
    // ledger and SUM() naturally cancels them out.
    await insertTx(
        signedAmountKobo: 1000, type: 'credit', referenceType: 'reward');
    await insertTx(
        signedAmountKobo: -1000, type: 'debit', referenceType: 'void');

    final balance = await db.customersDao.getWalletBalanceKobo(customerId);
    // 5000 + (-2000) + 1000 + (-1000) = 3000.
    expect(balance, equals(3000));
  });

  test('watchAllWalletBalancesKobo aggregates per customer', () async {
    final customerId2 = await db.customersDao.addCustomer(
      CustomersCompanion.insert(businessId: businessId, name: 'Bob'),
    );
    final wallet2 = await (db.select(db.customerWallets)
          ..where((t) => t.customerId.equals(customerId2)))
        .getSingle();

    await insertTx(
        signedAmountKobo: 5000, type: 'credit', referenceType: 'topup_cash');
    // Reward + compensating void → 0 net effect for this customer.
    await insertTx(
        signedAmountKobo: 999, type: 'credit', referenceType: 'reward');
    await insertTx(
        signedAmountKobo: -999, type: 'debit', referenceType: 'void');
    await db.into(db.walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            businessId: businessId,
            walletId: wallet2.id,
            customerId: customerId2,
            type: 'credit',
            amountKobo: 7000,
            signedAmountKobo: 7000,
            referenceType: 'topup_transfer',
          ),
        );

    final balances =
        await db.customersDao.watchAllWalletBalancesKobo().first;
    expect(balances[customerId], equals(5000));
    expect(balances[customerId2], equals(7000));
  });
}
