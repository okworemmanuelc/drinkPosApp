import 'dart:math';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'app_database.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Suppliers, Products, Categories, Warehouses])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);
  Stream<List<SupplierData>> watchAllSupplierDatas() => select(suppliers).watch();
  Future<int> insertSupplier(SuppliersCompanion companion) => into(suppliers).insert(companion);
  Future<int> insertProduct(ProductsCompanion companion) => into(products).insert(companion);

  Future<List<String>> getDistinctManufacturers() async {
    final query = selectOnly(products, distinct: true)
      ..addColumns([products.manufacturer])
      ..where(products.manufacturer.isNotNull() & products.isDeleted.not());
    final rows = await query.get();
    return rows
        .map((r) => r.read(products.manufacturer))
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  Stream<List<ProductData>> watchAvailableProductDatas({int? categoryId}) {
    if (categoryId != null) {
      return (select(products)..where((t) => t.isDeleted.not() & t.categoryId.equals(categoryId))).watch();
    }
    return (select(products)..where((t) => t.isDeleted.not())).watch();
  }
  Future<ProductData?> findById(int id) => (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<void> softDeleteProduct(int productId) => (update(products)..where((t) => t.id.equals(productId))).write(const ProductsCompanion(isDeleted: Value(true)));

  int getPriceForCustomerGroup(ProductData product, String group) {
    switch (group) {
      case 'bulk_breaker':
        return product.bulkBreakerPriceKobo ?? product.retailPriceKobo;
      case 'distributor':
        return product.distributorPriceKobo ?? product.retailPriceKobo;
      default:
        return product.retailPriceKobo;
    }
  }
}

@DriftAccessor(tables: [Products, Inventory, Warehouses, CrateGroups])
class InventoryDao extends DatabaseAccessor<AppDatabase> with _$InventoryDaoMixin {
  InventoryDao(super.db);

  Stream<List<ProductDataWithStock>> watchAllProductDatasWithStock() {
    final qty = inventory.quantity.sum();
    final query = select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..where(products.isDeleted.not())
      ..groupBy([products.id])
      ..addColumns([qty]);
    return query.watch().map((rows) => rows
        .map((row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ))
        .toList());
  }

  Stream<List<ProductDataWithStock>> watchLowStockProductDatas() {
    final qty = inventory.quantity.sum();
    final query = select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..where(products.isDeleted.not())
      ..groupBy([products.id])
      ..addColumns([qty]);
    return query.watch().map((rows) => rows
        .map((row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ))
        .where((p) => p.totalStock > 0 && p.totalStock <= p.product.lowStockThreshold)
        .toList());
  }

  Stream<List<ProductDataWithStock>> watchProductDatasWithStockByWarehouse(int warehouseId) {
    final qty = inventory.quantity.sum();
    final query = select(products).join([
      leftOuterJoin(
        inventory,
        inventory.productId.equalsExp(products.id) & inventory.warehouseId.equals(warehouseId),
      ),
    ])
      ..where(products.isDeleted.not())
      ..groupBy([products.id])
      ..addColumns([qty]);
    return query.watch().map((rows) => rows
        .map((row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ))
        .toList());
  }

  Future<void> deductStock(int productId, int warehouseId, int qty) async {
    await transaction(() async {
      final row = await (select(inventory)
            ..where((t) => t.productId.equals(productId) & t.warehouseId.equals(warehouseId)))
          .getSingleOrNull();
      if (row != null) {
        final newQty = (row.quantity - qty).clamp(0, 999999);
        await (update(inventory)..where((t) => t.id.equals(row.id)))
            .write(InventoryCompanion(quantity: Value(newQty)));
      }
    });
  }

  Future<void> adjustStock(int productId, int warehouseId, int delta, String note, int? staffId) async {
    await transaction(() async {
      final existing = await (select(inventory)
            ..where((t) => t.productId.equals(productId) & t.warehouseId.equals(warehouseId)))
          .getSingleOrNull();
      if (existing != null) {
        final newQty = (existing.quantity + delta).clamp(0, 999999);
        await (update(inventory)..where((t) => t.id.equals(existing.id)))
            .write(InventoryCompanion(quantity: Value(newQty)));
      } else if (delta > 0) {
        await into(inventory).insert(InventoryCompanion.insert(
          productId: productId,
          warehouseId: warehouseId,
          quantity: Value(delta),
        ));
      }
    });
  }

  Stream<List<CrateGroupData>> watchAllCrateGroups() => select(crateGroups).watch();
  Future<List<CrateGroupData>> getAllCrateGroups() => select(crateGroups).get();

  Future<void> assignCrateGroup(int productId, int? crateGroupId, String? crateSize) async {
    await (update(products)..where((t) => t.id.equals(productId)))
        .write(ProductsCompanion(
          crateGroupId: Value(crateGroupId),
          crateSize: Value(crateSize),
        ));
  }

  Future<void> addEmptyCrates(int crateGroupId, int quantity) async {
    final row = await (select(crateGroups)..where((t) => t.id.equals(crateGroupId))).getSingleOrNull();
    if (row != null) {
      await (update(crateGroups)..where((t) => t.id.equals(crateGroupId)))
          .write(CrateGroupsCompanion(emptyCrateStock: Value(row.emptyCrateStock + quantity)));
    }
  }

  Future<void> deductEmptyCrates(int crateGroupId, int quantity) async {
    final row = await (select(crateGroups)..where((t) => t.id.equals(crateGroupId))).getSingleOrNull();
    if (row != null) {
      final newStock = (row.emptyCrateStock - quantity).clamp(0, 999999);
      await (update(crateGroups)..where((t) => t.id.equals(crateGroupId)))
          .write(CrateGroupsCompanion(emptyCrateStock: Value(newStock)));
    }
  }
}

class ProductDataWithStock {
  final ProductData product;
  final int totalStock;
  ProductDataWithStock({required this.product, required this.totalStock});
}

@DriftAccessor(tables: [Orders, OrderItems, Products, Customers])
class OrdersDao extends DatabaseAccessor<AppDatabase> with _$OrdersDaoMixin {
  OrdersDao(super.db);
  Stream<List<OrderData>> watchPendingOrders() => (select(orders)..where((t) => t.status.equals('pending'))).watch();
  Stream<List<OrderData>> watchAllOrders() => select(orders).watch();
  Stream<List<OrderData>> watchOrdersByWarehouse(int? warehouseId) => select(orders).watch();
  Stream<List<OrderWithItems>> watchAllOrdersWithItems() => Stream.value([]);
  Stream<List<OrderData>> watchCompletedOrders() => (select(orders)..where((t) => t.status.equals('completed'))).watch();
  Stream<List<OrderData>> watchCancelledOrders() => (select(orders)..where((t) => t.status.equals('cancelled'))).watch();
  Future<void> markCompleted(int orderId, int staffId) async {}
  Future<void> markCancelled(int orderId, String reason, int staffId) async {}
  Future<void> assignRider(int orderId, String riderName) async {}
  Future<String> createOrder({
    required OrdersCompanion order,
    required List<OrderItemsCompanion> items,
    int? customerId,
    required int amountPaidKobo,
    required int totalAmountKobo,
    required int staffId,
  }) async {
    return transaction(() async {
      // 1. Generate Order Number
      final orderNo = await generateOrderNumber();
      final orderWithNo = order.copyWith(orderNumber: Value(orderNo));

      // 2. Insert Order
      final orderId = await into(orders).insert(orderWithNo);

      // 3. Insert Items
      for (final item in items) {
        await into(orderItems).insert(item.copyWith(orderId: Value(orderId)));
      }

      // 4. Update Wallet if there's a balance remaining (Debit/Credit Sale)
      if (customerId != null) {
        final remainingBalance = totalAmountKobo - amountPaidKobo;
        if (remainingBalance > 0) {
          // This is a debit to the customer (they owe more)
          await (db.customersDao).updateWalletBalance(
            customerId: customerId,
            deltaKobo: remainingBalance,
            type: 'debit',
            referenceType: 'order_payment',
            referenceId: orderNo,
            staffId: staffId,
            note: 'Balance from order $orderNo',
          );
        }
      }

      return orderNo;
    });
  }

  Future<String> generateOrderNumber() async {
    final count = await (select(orders)).get();
    final nextId = count.length + 1;
    final dateStr = DateFormat('yyMMdd').format(DateTime.now());
    return 'ORD-$dateStr-${nextId.toString().padLeft(4, '0')}';
  }
}

class OrderWithItems {
  final OrderData order;
  final List<OrderItemDataWithProductData> items;
  final CustomerData? customer;
  OrderWithItems(this.order, this.items, this.customer);
}

class OrderItemDataWithProductData {
  final OrderItemData item;
  final ProductData product;
  OrderItemDataWithProductData(this.item, this.product);
}

@DriftAccessor(tables: [Customers, CustomerWalletTransactions, CustomerCrateBalances, CustomerWallets, WalletTransactions])
class CustomersDao extends DatabaseAccessor<AppDatabase> with _$CustomersDaoMixin {
  CustomersDao(super.db);
  Stream<List<CustomerData>> watchAllCustomers() => (select(customers)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();
  Future<CustomerData?> findById(int id) => (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<CustomerData?> findByPhone(String phone) => (select(customers)..where((t) => t.phone.equals(phone))).getSingleOrNull();
  
  Future<void> addCustomer(CustomersCompanion customer) async {
    return transaction(() async {
      final customerId = await into(customers).insert(customer);
      
      // Every customer must have a wallet
      final walletId = _generateUuid();
      await into(customerWallets).insert(CustomerWalletsCompanion.insert(
        walletId: walletId,
        customerId: customerId,
      ));
    });
  }

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return 'wlt-$random'; // Simple unique wallet ID
  }

  Future<void> updateWalletBalance({
    required int customerId,
    required int deltaKobo,
    required String type, // credit or debit
    required String referenceType,
    String? referenceId,
    required int staffId,
    String? note,
  }) async {
    return transaction(() async {
      final wallet = await (select(customerWallets)
            ..where((t) => t.customerId.equals(customerId)))
          .getSingleOrNull();

      if (wallet == null) throw Exception('Customer wallet not found');

      // 1. Update the cached balance in Customers table for quick access
      final customer = await findById(customerId);
      if (customer != null) {
        final newBalance = customer.walletBalanceKobo + (type == 'credit' ? deltaKobo : -deltaKobo);
        await (update(customers)..where((t) => t.id.equals(customerId)))
            .write(CustomersCompanion(walletBalanceKobo: Value(newBalance)));
      }

      // 2. Insert into WalletTransactions for audit trail
      final txnId = 'txn-${DateTime.now().microsecondsSinceEpoch}';
      await into(walletTransactions).insert(WalletTransactionsCompanion.insert(
        txnId: txnId,
        walletId: wallet.walletId,
        type: type,
        amountKobo: deltaKobo.abs(),
        referenceType: referenceType,
        referenceId: Value(referenceId),
        performedBy: staffId,
        createdAt: Value(DateTime.now()),
      ));
    });
  }

  Stream<List<WalletTransactionData>> watchWalletHistory(int customerId) {
    final query = select(walletTransactions).join([
      innerJoin(customerWallets, customerWallets.walletId.equalsExp(walletTransactions.walletId)),
    ])
      ..where(customerWallets.customerId.equals(customerId))
      ..orderBy([OrderingTerm.desc(walletTransactions.createdAt)]);

    return query.watch().map((rows) => rows.map((r) => r.readTable(walletTransactions)).toList());
  }

  Future<CustomerWalletData?> getWalletInfo(int customerId) {
    return (select(customerWallets)..where((t) => t.customerId.equals(customerId))).getSingleOrNull();
  }

  Future<void> updateWalletLimit(int customerId, int limitKobo) {
    return (update(customers)..where((t) => t.id.equals(customerId)))
        .write(CustomersCompanion(walletLimitKobo: Value(limitKobo)));
  }

  Stream<int> watchWalletBalance(int customerId) {
    return (select(customers)..where((t) => t.id.equals(customerId)))
        .watchSingleOrNull()
        .map((c) => c?.walletBalanceKobo ?? 0);
  }

  Future<void> updateCrateBalance(int customerId, int crateGroupId, int deltaQty) async {}
  Stream<Map<String, int>> watchCrateBalance(int customerId) => Stream.value({});

  Future<int> getWalletBalance(String walletId) async {
    final credits = walletTransactions.amountKobo.sum(filter: walletTransactions.type.equals('credit'));
    final debits = walletTransactions.amountKobo.sum(filter: walletTransactions.type.equals('debit'));

    final query = selectOnly(walletTransactions)
      ..addColumns([credits, debits])
      ..where(walletTransactions.walletId.equals(walletId));

    final row = await query.getSingle();
    final creditSum = row.read(credits) ?? 0;
    final debitSum = row.read(debits) ?? 0;

    return creditSum - debitSum;
  }
}

@DriftAccessor(tables: [Purchases, PurchaseItems, Suppliers, Products])
class DeliveriesDao extends DatabaseAccessor<AppDatabase> with _$DeliveriesDaoMixin {
  DeliveriesDao(super.db);
  Stream<List<DeliveryData>> watchAll() => select(purchases).watch();
  Future<void> receiveDelivery(PurchasesCompanion delivery, List<PurchaseItemsCompanion> items) async {}
  Future<void> confirmDelivery(String deliveryIdStr, String confirmedBy) async {}
}

@DriftAccessor(tables: [Expenses, ExpenseCategories])
class ExpensesDao extends DatabaseAccessor<AppDatabase> with _$ExpensesDaoMixin {
  ExpensesDao(super.db);
  Stream<List<ExpenseData>> watchAll() => select(expenses).watch();
  Future<void> addExpense(ExpensesCompanion companion) => into(expenses).insert(companion);
  Stream<double> watchTotalThisMonth() => Stream.value(0.0);
}

@DriftAccessor(tables: [SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);
  Future<List<SyncQueueData>> getPendingItems({int limit = 50}) => (select(syncQueue)..where((t) => t.isSynced.not())..limit(limit)).get();
  Future<void> markInProgress(int id) => (update(syncQueue)..where((t) => t.id.equals(id))).write(const SyncQueueCompanion(status: Value('in_progress')));
  Future<void> markDone(int id) => (update(syncQueue)..where((t) => t.id.equals(id))).write(const SyncQueueCompanion(status: Value('done'), isSynced: Value(true)));
  Future<void> markFailed(int id, String error, {bool permanent = false}) => (update(syncQueue)..where((t) => t.id.equals(id))).write(SyncQueueCompanion(status: const Value('failed'), errorMessage: Value(error)));
  Stream<int> watchPendingCount() => select(syncQueue).watch().map((l) => l.where((e) => !e.isSynced).length);
  Future<void> purgeOldDoneItems() => (delete(syncQueue)..where((t) => t.isSynced)).go();
}

@DriftAccessor(tables: [ActivityLogs])
class ActivityLogDao extends DatabaseAccessor<AppDatabase> with _$ActivityLogDaoMixin {
  ActivityLogDao(super.db);
  Future<void> log({int? staffId, required String action, required String description, String? entityId, String? entityType, String? warehouseId}) => into(activityLogs).insert(ActivityLogsCompanion.insert(userId: Value(staffId), action: action, description: description, relatedEntityId: Value(entityId), relatedEntityType: Value(entityType), warehouseId: Value(warehouseId)));
  Stream<List<ActivityLogData>> watchRecent({int limit = 100}) => (select(activityLogs)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])..limit(limit)).watch();
  Future<List<ActivityLogData>> getForEntity(String entityId) => (select(activityLogs)..where((t) => t.relatedEntityId.equals(entityId))).get();
}

@DriftAccessor(tables: [Users, Warehouses])
class WarehousesDao extends DatabaseAccessor<AppDatabase> with _$WarehousesDaoMixin {
  WarehousesDao(super.db);
  Stream<List<UserData>> watchAllStaff() => select(users).watch();
  Stream<List<UserData>> watchStaffByWarehouse(int warehouseId) => (select(users)..where((t) => t.warehouseId.equals(warehouseId))).watch();
  Future<void> assignStaffToWarehouse(int userId, int? warehouseId) => (update(users)..where((t) => t.id.equals(userId))).write(UsersCompanion(warehouseId: Value(warehouseId)));
  Stream<Map<int, int>> watchWarehouseStaffCounts() => Stream.value({});
}

@DriftAccessor(tables: [Notifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase> with _$NotificationsDaoMixin {
  NotificationsDao(super.db);
  Future<void> create(String type, String message, {String? linkedRecordId}) => into(notifications).insert(NotificationsCompanion.insert(type: type, message: message, linkedRecordId: Value(linkedRecordId)));
  Stream<List<NotificationData>> watchAll() => (select(notifications)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  Stream<int> watchUnreadCount() => select(notifications).watch().map((l) => l.where((e) => !e.isRead).length);
  Future<void> markRead(int id) => (update(notifications)..where((t) => t.id.equals(id))).write(const NotificationsCompanion(isRead: Value(true)));
  Future<void> markAllRead() => update(notifications).write(const NotificationsCompanion(isRead: Value(true)));
}

@DriftAccessor(tables: [StockTransactions, Products])
class StockLedgerDao extends DatabaseAccessor<AppDatabase> with _$StockLedgerDaoMixin {
  StockLedgerDao(super.db);

  Future<int> getCurrentStock(int productId, int locationId) {
    final delta = stockTransactions.quantityDelta.sum();
    return (selectOnly(stockTransactions)
          ..where(stockTransactions.productId.equals(productId))
          ..where(stockTransactions.locationId.equals(locationId))
          ..addColumns([delta]))
        .map((row) => row.read(delta) ?? 0)
        .getSingle();
  }

  Stream<int> watchCurrentStock(int productId, int locationId) {
    final delta = stockTransactions.quantityDelta.sum();
    return (selectOnly(stockTransactions)
          ..where(stockTransactions.productId.equals(productId))
          ..where(stockTransactions.locationId.equals(locationId))
          ..addColumns([delta]))
        .map((row) => row.read(delta) ?? 0)
        .watchSingle();
  }

  Future<void> insertTransaction(StockTransactionsCompanion companion) => into(stockTransactions).insert(companion);
  
  Stream<List<StockTransactionData>> watchLedger(int productId) {
    return (select(stockTransactions)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<ProductBelowROP>> getProductsBelowROP(int locationId) async {
    final qty = stockTransactions.quantityDelta.sum();
    

    final query = (selectOnly(products)
      ..addColumns([products.id, products.name, products.avgDailySales, products.leadTimeDays, products.safetyStockQty, qty])
      ..join([
        leftOuterJoin(stockTransactions, stockTransactions.productId.equalsExp(products.id)),
      ]))
      ..where(stockTransactions.locationId.equals(locationId) | stockTransactions.locationId.isNull())
      ..groupBy([products.id]);

    final results = await query.get();
    return results.map((row) {
      final productId = row.read(products.id)!;
      final productName = row.read(products.name)!;
      final avgDailySales = row.read(products.avgDailySales)!;
      final leadTimeDays = row.read(products.leadTimeDays)!;
      final safetyStockQty = row.read(products.safetyStockQty)!;
      final currentStock = row.read(qty) ?? 0;
      
      final computedROP = (avgDailySales * leadTimeDays) + safetyStockQty;
      
      return ProductBelowROP(
        productId: productId,
        productName: productName,
        currentStock: currentStock.toInt(),
        rop: computedROP.toDouble(),
      );
    }).where((p) => p.currentStock <= p.rop).toList();
  }
}

class ProductBelowROP {
  final int productId;
  final String productName;
  final int currentStock;
  final double rop;

  ProductBelowROP({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.rop,
  });
}

@DriftAccessor(tables: [StockTransfers, StockTransactions])
class StockTransferDao extends DatabaseAccessor<AppDatabase> with _$StockTransferDaoMixin {
  StockTransferDao(super.db);

  String _generateUuid() => '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(10000)}';

  Future<void> initiateTransfer(StockTransfersCompanion companion) async {
    await transaction(() async {
      final id = await into(stockTransfers).insert(companion.copyWith(status: const Value('pending'), initiatedAt: Value(DateTime.now())));
      await into(attachedDatabase.stockTransactions).insert(StockTransactionsCompanion.insert(transactionId: _generateUuid(), productId: companion.productId.value, locationId: companion.fromLocationId.value, quantityDelta: -companion.quantity.value, movementType: 'transfer_out', referenceId: Value(id.toString()), performedBy: companion.initiatedBy.value, createdAt: Value(DateTime.now())));
    });
  }

  Future<void> receiveTransfer(int transferId, int receivedBy) async {
    await transaction(() async {
      final transfer = await (select(stockTransfers)..where((t) => t.transferId.equals(transferId))).getSingle();
      if (transfer.status != 'pending' && transfer.status != 'in_transit') throw Exception('Transfer cannot be received');
      await (update(stockTransfers)..where((t) => t.transferId.equals(transferId))).write(StockTransfersCompanion(status: const Value('received'), receivedBy: Value(receivedBy), receivedAt: Value(DateTime.now())));
      await into(attachedDatabase.stockTransactions).insert(StockTransactionsCompanion.insert(transactionId: _generateUuid(), productId: transfer.productId, locationId: transfer.toLocationId, quantityDelta: transfer.quantity, movementType: 'transfer_in', referenceId: Value(transferId.toString()), performedBy: receivedBy, createdAt: Value(DateTime.now())));
    });
  }

  Future<void> cancelTransfer(int transferId) async {
    await transaction(() async {
      final transfer = await (select(stockTransfers)..where((t) => t.transferId.equals(transferId))).getSingle();
      if (transfer.status == 'received') throw Exception('Cannot cancel received transfer');
      await (update(stockTransfers)..where((t) => t.transferId.equals(transferId))).write(const StockTransfersCompanion(status: Value('cancelled')));
      final tx = await (select(attachedDatabase.stockTransactions)..where((t) => t.referenceId.equals(transferId.toString()) & t.movementType.equals('transfer_out'))).getSingleOrNull();
      if (tx != null) {
        await into(attachedDatabase.stockTransactions).insert(StockTransactionsCompanion.insert(transactionId: _generateUuid(), productId: transfer.productId, locationId: transfer.fromLocationId, quantityDelta: transfer.quantity, movementType: 'transfer_cancelled', referenceId: Value(transferId.toString()), performedBy: transfer.initiatedBy, createdAt: Value(DateTime.now())));
      }
    });
  }
}

extension CustomerDataExtension on CustomerData {
  String get addressText => address ?? 'N/A';
  double get customerWallet => walletBalanceKobo / 100.0;
}
