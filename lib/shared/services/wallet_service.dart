import 'package:drift/drift.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

class WalletService {
  final AppDatabase _db;

  WalletService(this._db);

  WalletTransactionsDao get _walletTxDao => _db.walletTransactionsDao;
  CustomerWalletsDao get _customerWalletsDao => _db.customerWalletsDao;

  /// Top up a customer's wallet.
  /// 
  /// Creates a WalletTransaction (credit) and a corresponding PaymentTransaction (wallet_topup).
  Future<void> topup({
    required String customerId,
    required int amountKobo,
    required String method, // 'cash' or 'transfer'
    required String staffId,
  }) async {
    final businessId = _walletTxDao.requireBusinessId();
    final wallet = await _customerWalletsDao.getByCustomerId(customerId);
    
    if (wallet == null) {
      throw StateError('Customer $customerId has no wallet');
    }

    await _db.transaction(() async {
      final walletTxnId = UuidV7.generate();
      final paymentTxnId = UuidV7.generate();

      // 1. Insert WalletTransactions row
      final walletComp = WalletTransactionsCompanion.insert(
        id: Value(walletTxnId),
        businessId: businessId,
        walletId: wallet.id,
        customerId: customerId,
        type: 'credit',
        amountKobo: amountKobo,
        signedAmountKobo: amountKobo,
        referenceType: method == 'cash' ? 'topup_cash' : 'topup_transfer',
        performedBy: Value(staffId),
        lastUpdatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.walletTransactions).insert(walletComp);
      await _db.syncDao.enqueueUpsert('wallet_transactions', walletComp);

      // 2. Insert PaymentTransactions row
      final paymentComp = PaymentTransactionsCompanion.insert(
        id: Value(paymentTxnId),
        businessId: businessId,
        amountKobo: amountKobo,
        method: method,
        type: 'wallet_topup',
        walletTxnId: Value(walletTxnId),
        performedBy: Value(staffId),
        lastUpdatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.paymentTransactions).insert(paymentComp);
      await _db.syncDao.enqueueUpsert('payment_transactions', paymentComp);
    });
  }

  /// Refunds any wallet debit associated with an order.
  /// 
  /// Appends a new credit transaction. The original debit remains untouched.
  Future<void> refundOrderWalletDebit({
    required String orderId,
    required String staffId,
  }) async {
    final businessId = _walletTxDao.requireBusinessId();

    // Find the original wallet debit for this order
    final originalDebit = await (_db.select(_db.walletTransactions)
          ..where(
            (t) =>
                t.businessId.equals(businessId) &
                t.orderId.equals(orderId) &
                t.type.equals('debit'),
          )
          ..limit(1))
        .getSingleOrNull();

    if (originalDebit == null) return;

    final refundId = UuidV7.generate();
    final refundComp = WalletTransactionsCompanion.insert(
      id: Value(refundId),
      businessId: businessId,
      walletId: originalDebit.walletId,
      customerId: originalDebit.customerId,
      type: 'credit',
      amountKobo: originalDebit.amountKobo,
      signedAmountKobo: originalDebit.amountKobo,
      referenceType: 'refund',
      orderId: Value(orderId),
      performedBy: Value(staffId),
      lastUpdatedAt: Value(DateTime.now()),
    );
    await _db.into(_db.walletTransactions).insert(refundComp);
    await _db.syncDao.enqueueUpsert('wallet_transactions', refundComp);
  }

  /// Calculates the current balance for a customer.
  Future<int> getBalanceKobo(String customerId) => _walletTxDao.getBalanceKobo(customerId);

  /// Watches the current balance for a customer.
  Stream<int> watchBalanceKobo(String customerId) => _walletTxDao.watchBalanceKobo(customerId);

  /// Voids a wallet transaction using a compensating entry.
  Future<void> voidTransaction({
    required String transactionId,
    required String voidedBy,
    required String reason,
  }) => _walletTxDao.voidTransaction(
    transactionId: transactionId,
    voidedBy: voidedBy,
    reason: reason,
  );
}
