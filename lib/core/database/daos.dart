import 'dart:math';
import 'package:drift/drift.dart';
import 'app_database.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Suppliers, Products, Categories, Warehouses])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);
  Stream<List<SupplierData>> watchAllSupplierDatas() => select(suppliers).watch();
  Future<int> insertSupplier(SuppliersCompanion companion) => into(suppliers).insert(companion);
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
  Stream<List<ProductDataWithStock>> watchAllProductDatasWithStock() => Stream.value([]); // Placeholder
  Future<void> deductStock(int productId, int warehouseId, int qty) async {}
  Future<void> adjustStock(int productId, int warehouseId, int delta, String note, int? staffId) async {}
  Stream<List<ProductDataWithStock>> watchLowStockProductDatas() => Stream.value([]);
  Stream<List<ProductDataWithStock>> watchProductDatasWithStockByWarehouse(int warehouseId) => Stream.value([]);
  Stream<List<CrateGroupData>> watchAllCrateGroups() => select(crateGroups).watch();
  Future<List<CrateGroupData>> getAllCrateGroups() => select(crateGroups).get();
  Future<void> assignCrateGroup(int productId, int? crateGroupId, String? crateSize) async {}
  Future<void> addEmptyCrates(int crateGroupId, int quantity) async {}
  Future<void> deductEmptyCrates(int crateGroupId, int quantity) async {}
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
  Future<String> generateOrderNumber() async => 'ORD-${DateTime.now().millisecondsSinceEpoch}';
  Future<String> createOrder({required OrdersCompanion order, required List<OrderItemsCompanion> items, int? customerId, required String paymentType, required int amountPaidKobo}) async => '';
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

@DriftAccessor(tables: [Customers, CustomerWalletTransactions, CustomerCrateBalances])
class CustomersDao extends DatabaseAccessor<AppDatabase> with _$CustomersDaoMixin {
  CustomersDao(super.db);
  Stream<List<CustomerData>> watchAllCustomers() => select(customers).watch();
  Future<CustomerData?> findById(int id) => (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<CustomerData?> findByPhone(String phone) => (select(customers)..where((t) => t.phone.equals(phone))).getSingleOrNull();
  Future<void> addCustomer(CustomersCompanion customer) => into(customers).insert(customer);
  Future<void> updateWalletBalance({required int customerId, required int deltaKobo, required String type, required int staffId, int? orderId, String? note}) async {}
  Future<void> updateCrateBalance(int customerId, int crateGroupId, int deltaQty) async {}
  Stream<List<CustomerWalletTransactionData>> watchWalletHistory(int customerId) => (select(customerWalletTransactions)..where((t) => t.customerId.equals(customerId))).watch();
  Stream<Map<String, int>> watchCrateBalance(int customerId) => Stream.value({});
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

@DriftAccessor(tables: [StockTransactions])
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
