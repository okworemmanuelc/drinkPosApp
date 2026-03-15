import 'dart:math';
import 'package:drift/drift.dart';
import 'app_database.dart';
import 'package:ribaplus_pos/features/customers/data/models/customer.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Products, Categories, AppSettings])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  Stream<List<ProductData>> watchAvailableProductDatas({int? categoryId}) {
    final query = select(products)..where((t) => t.isAvailable.equals(true) & t.isDeleted.equals(false));
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    return query.watch();
  }

  Future<ProductData?> findById(int id) {
    return (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  int getPriceForCustomerGroup(ProductData p, String customerGroup) {
    switch (customerGroup.toLowerCase()) {
      case 'retail':
        return p.retailPriceKobo;
      case 'bulk_breaker':
        return p.bulkBreakerPriceKobo ?? p.sellingPriceKobo;
      case 'distributor':
        return p.distributorPriceKobo ?? p.sellingPriceKobo;
      default:
        return p.sellingPriceKobo;
    }
  }
}

class ProductDataWithStock {
  final ProductData product;
  final int totalStock;

  ProductDataWithStock({required this.product, required this.totalStock});
}

@DriftAccessor(tables: [Products, Inventory, StockAdjustments, SyncQueue])
class InventoryDao extends DatabaseAccessor<AppDatabase> with _$InventoryDaoMixin {
  InventoryDao(super.db);

  Stream<List<ProductDataWithStock>> watchAllProductDatasWithStock() {
    return select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ]).watch().map((rows) {
      final Map<int, ProductDataWithStock> results = {};
      
      for (final row in rows) {
        final product = row.readTable(products);
        final inv = row.readTableOrNull(inventory);
        final qty = inv?.quantity ?? 0;
        
        if (results.containsKey(product.id)) {
          results[product.id] = ProductDataWithStock(
            product: product,
            totalStock: results[product.id]!.totalStock + qty,
          );
        } else {
          results[product.id] = ProductDataWithStock(product: product, totalStock: qty);
        }
      }
      return results.values.toList();
    });
  }

  Future<void> deductStock(int productId, int warehouseId, int qty) async {
    await transaction(() async {
      final existing = await (select(inventory)
            ..where((t) => t.productId.equals(productId) & t.warehouseId.equals(warehouseId)))
          .getSingleOrNull();

      if (existing != null) {
        await (update(inventory)
              ..where((t) => t.id.equals(existing.id)))
            .write(InventoryCompanion(quantity: Value(existing.quantity - qty)));
      }
    });
  }

  Future<void> adjustStock(int productId, int warehouseId, int delta, String note, int? staffId) async {
    await transaction(() async {
      // 1. Update/Insert inventory
      final existing = await (select(inventory)
            ..where((t) => t.productId.equals(productId) & t.warehouseId.equals(warehouseId)))
          .getSingleOrNull();

      if (existing != null) {
        await (update(inventory)
              ..where((t) => t.id.equals(existing.id)))
            .write(InventoryCompanion(quantity: Value(existing.quantity + delta)));
      } else {
        await into(inventory).insert(InventoryCompanion.insert(
          productId: productId,
          warehouseId: warehouseId,
          quantity: Value(delta),
        ));
      }

      // 2. Log adjustment
      await into(stockAdjustments).insert(StockAdjustmentsCompanion.insert(
        productId: productId,
        warehouseId: warehouseId,
        quantityDiff: delta,
        reason: note,
        timestamp: Value(DateTime.now()),
      ));

      // 3. Queue cloud sync
      await into(attachedDatabase.syncQueue).insert(SyncQueueCompanion.insert(
        actionType: 'UPDATE_INVENTORY',
        payload: '{"productId": $productId, "warehouseId": $warehouseId}',
        createdAt: Value(DateTime.now()),
      ));
    });
  }

  Stream<List<ProductDataWithStock>> watchLowStockProductDatas() {
    return watchAllProductDatasWithStock().map((list) {
      return list.where((item) => item.totalStock <= item.product.lowStockThreshold).toList();
    });
  }
}

class OrderItemDataWithProductData {
  final OrderItemData item;
  final ProductData product;
  OrderItemDataWithProductData(this.item, this.product);
}

class OrderWithItems {
  final OrderData order;
  final List<OrderItemDataWithProductData> items;
  final Customer? customer;
  OrderWithItems(this.order, this.items, this.customer);
}

@DriftAccessor(tables: [
  Orders,
  OrderItems,
  Customers,
  Products,
  Inventory,
  CustomerCrateBalances,
  SyncQueue,
  ActivityLogs,
  AppSettings,
])
class OrdersDao extends DatabaseAccessor<AppDatabase> with _$OrdersDaoMixin {
  OrdersDao(super.db);

  Stream<List<OrderData>> watchPendingOrders() {
    return (select(orders)..where((t) => t.status.equals('pending'))..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Stream<List<OrderData>> watchAllOrders() {
    return (select(orders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Stream<List<OrderWithItems>> watchAllOrdersWithItems() {
    final query = select(orders).join([
      leftOuterJoin(orderItems, orderItems.orderId.equalsExp(orders.id)),
      leftOuterJoin(customers, customers.id.equalsExp(orders.customerId)),
      leftOuterJoin(products, products.id.equalsExp(orderItems.productId)),
    ]);
    query.orderBy([OrderingTerm.desc(orders.createdAt)]);

    return query.watch().map((rows) {
      final grouped = <int, OrderWithItems>{};
      for (final row in rows) {
        final order = row.readTable(orders);
        final item = row.readTableOrNull(orderItems);
        final customer = row.readTableOrNull(customers);
        final product = row.readTableOrNull(products);
        
        grouped.putIfAbsent(
          order.id,
          () => OrderWithItems(
            order,
            [],
            customer != null ? Customer.fromDb(customer) : null,
          ),
        );
        
        if (item != null && product != null) {
          grouped[order.id]!.items.add(OrderItemDataWithProductData(item, product));
        }
      }
      return grouped.values.toList();
    });
  }

  Stream<List<OrderData>> watchCompletedOrders() {
    return (select(orders)..where((t) => t.status.equals('completed'))..orderBy([(t) => OrderingTerm.desc(t.completedAt)])).watch();
  }

  Stream<List<OrderData>> watchCancelledOrders() {
    return (select(orders)..where((t) => t.status.equals('cancelled'))..orderBy([(t) => OrderingTerm.desc(t.cancelledAt)])).watch();
  }

  Future<void> markCompleted(int orderId, int staffId) async {
    await (update(orders)..where((t) => t.id.equals(orderId))).write(OrdersCompanion(
      status: const Value('completed'),
      completedAt: Value(DateTime.now()),
    ));
    
    // Log action
    await into(activityLogs).insert(ActivityLogsCompanion.insert(
      userId: Value(staffId),
      action: 'Completed Order #$orderId',
      description: 'Order marked as completed by staff #$staffId',
      timestamp: Value(DateTime.now()),
    ));
  }

  Future<void> markCancelled(int orderId, String reason, int staffId) async {
    await (update(orders)..where((t) => t.id.equals(orderId))).write(OrdersCompanion(
      status: const Value('cancelled'),
      cancelledAt: Value(DateTime.now()),
      cancellationReason: Value(reason),
    ));

    // Log action
    await into(activityLogs).insert(ActivityLogsCompanion.insert(
      userId: Value(staffId),
      action: 'Cancelled Order #$orderId: $reason',
      description: 'Order cancelled. Reason: $reason',
      timestamp: Value(DateTime.now()),
    ));
  }

  Future<void> assignRider(int orderId, String riderName) async {
    await (update(orders)..where((t) => t.id.equals(orderId))).write(OrdersCompanion(
      riderName: Value(riderName),
    ));
  }

  Future<String> generateOrderNumber() async {
    final today = DateTime.now();
    final dateStr = "${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}";
    final key = "order_seq_$dateStr";

    final setting = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    int nextSeq = 1;
    if (setting != null) {
      nextSeq = int.parse(setting.value) + 1;
      await (update(appSettings)..where((t) => t.key.equals(key))).write(AppSettingsCompanion(value: Value(nextSeq.toString())));
    } else {
      await into(appSettings).insert(AppSettingsCompanion.insert(key: key, value: "1"));
    }

    return "ORD-$dateStr-${nextSeq.toString().padLeft(3, '0')}";
  }

  String _generateBarcode() {
    final random = Random();
    String barcode = '';
    for (int i = 0; i < 16; i++) {
      barcode += random.nextInt(10).toString();
    }
    return barcode;
  }

  Future<String> createOrder({
    required OrdersCompanion order,
    required List<OrderItemsCompanion> items,
    int? customerId,
    required String paymentType,
    required int amountPaidKobo,
  }) async {
    return transaction(() async {
      final orderNumber = await generateOrderNumber();
      final barcode = _generateBarcode();
      
      // 1. Insert into orders
      final finalOrderId = await into(orders).insert(order.copyWith(
        orderNumber: Value(orderNumber),
        barcode: Value(barcode),
        amountPaidKobo: Value(amountPaidKobo),
        createdAt: Value(DateTime.now()),
        status: const Value('pending'),
      ));

      int totalOrderKobo = 0;

      // 2. Insert all rows into order_items (with price snapshots)
      for (final item in items) {
        final itemTotal = item.totalKobo.value;
        totalOrderKobo += itemTotal;
        
        await into(orderItems).insert(item.copyWith(orderId: Value(finalOrderId)));

        // 3. Deduct stock_levels per warehouse
        final inventoryItem = await (select(inventory)
              ..where((t) => t.productId.equals(item.productId.value) & 
                             t.warehouseId.equals(item.warehouseId.value)))
            .getSingleOrNull();

        if (inventoryItem == null || inventoryItem.quantity < item.quantity.value) {
          throw Exception("Insufficient stock for product ID ${item.productId.value} in warehouse ${item.warehouseId.value}");
        }

        await (update(inventory)..where((t) => t.id.equals(inventoryItem.id)))
            .write(InventoryCompanion(
              quantity: Value(inventoryItem.quantity - item.quantity.value),
            ));

        // 5. Update customer_crate_balances
        final product = await (select(products)..where((t) => t.id.equals(item.productId.value))).getSingle();
        final cat = await (select(categories)..where((t) => t.id.equals(product.categoryId!))).getSingleOrNull();
        
        // Logic: if category is 'Glass Crates' or similar (based on needsCrate logic)
        // For now, let's assume we check a flag or category
        if (cat?.name.contains('Glass') == true && customerId != null) {
           final existingCrateBal = await (select(customerCrateBalances)
              ..where((t) => t.customerId.equals(customerId) & t.crateGroupId.equals(1))) // Default group 1 for now
            .getSingleOrNull();
           
           if (existingCrateBal != null) {
              await (update(customerCrateBalances)
                ..where((t) => t.customerId.equals(customerId) & t.crateGroupId.equals(1)))
              .write(CustomerCrateBalancesCompanion(balance: Value(existingCrateBal.balance + item.quantity.value)));
           } else {
              await into(customerCrateBalances).insert(CustomerCrateBalancesCompanion.insert(
                customerId: customerId,
                crateGroupId: 1,
                balance: Value(item.quantity.value),
              ));
           }
        }
      }

      // 4. Update customer wallet_balance_kobo
      if (customerId != null) {
        final customer = await (select(customers)..where((t) => t.id.equals(customerId))).getSingle();
        // Debt: amountPaid < totalOrderKobo. Balance decreases (becomes more negative if debt)
        // Payment: amountPaid > totalOrderKobo. Balance increases.
        final balanceChange = amountPaidKobo - totalOrderKobo;
        
        await (update(customers)..where((t) => t.id.equals(customerId)))
            .write(CustomersCompanion(
              walletBalanceKobo: Value(customer.walletBalanceKobo + balanceChange),
            ));
      }

      // 6. Insert into sync_queue
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        actionType: 'CREATE_ORDER',
        payload: '{"orderId": $finalOrderId, "orderNumber": "$orderNumber"}',
        createdAt: Value(DateTime.now()),
      ));

      // 7. Insert into activity_log
      await into(activityLogs).insert(ActivityLogsCompanion.insert(
        userId: order.staffId,
        action: 'Created Order #$orderNumber',
        description: 'New sale recorded with ${items.length} items',
        timestamp: Value(DateTime.now()),
      ));

      return orderNumber;
    });
  }
}

@DriftAccessor(tables: [Customers, CustomerWalletTransactions, CustomerCrateBalances, CrateGroups])
class CustomersDao extends DatabaseAccessor<AppDatabase> with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Stream<List<Customer>> watchAllCustomers() =>
      select(customers).watch().map((list) => list.map((d) => Customer.fromDb(d)).toList());

  Future<Customer?> findById(int id) async {
    final data = await (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
    return data != null ? Customer.fromDb(data) : null;
  }

  Future<Customer?> findByPhone(String phone) async {
    final data = await (select(customers)..where((t) => t.phone.equals(phone))).getSingleOrNull();
    return data != null ? Customer.fromDb(data) : null;
  }

  Future<void> addCustomer(CustomersCompanion customer) => into(customers).insert(customer);

  Future<void> updateWalletBalance({
    required int customerId,
    required int deltaKobo,
    required String type,
    required int staffId,
    int? orderId,
    String? note,
  }) async {
    return transaction(() async {
      final customer = await (select(customers)..where((t) => t.id.equals(customerId))).getSingle();
      
      await (update(customers)..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(walletBalanceKobo: Value(customer.walletBalanceKobo + deltaKobo))
      );

      await into(customerWalletTransactions).insert(
        CustomerWalletTransactionsCompanion.insert(
          customerId: customerId,
          amountDeltaKobo: deltaKobo,
          type: type,
          staffId: staffId,
          orderId: Value(orderId),
          note: Value(note),
          timestamp: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> updateCrateBalance(int customerId, int crateGroupId, int deltaQty) async {
    return transaction(() async {
      final existing = await (select(customerCrateBalances)
            ..where((t) => t.customerId.equals(customerId) & t.crateGroupId.equals(crateGroupId)))
          .getSingleOrNull();

      if (existing != null) {
        await (update(customerCrateBalances)
              ..where((t) => t.customerId.equals(customerId) & t.crateGroupId.equals(crateGroupId)))
            .write(CustomerCrateBalancesCompanion(balance: Value(existing.balance + deltaQty)));
      } else {
        await into(customerCrateBalances).insert(
          CustomerCrateBalancesCompanion.insert(
            customerId: customerId,
            crateGroupId: crateGroupId,
            balance: Value(deltaQty),
          ),
        );
      }
    });
  }

  Stream<List<CustomerWalletTransactionData>> watchWalletHistory(int customerId) =>
    (select(customerWalletTransactions)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();

  Stream<Map<String, int>> watchCrateBalance(int customerId) {
    return (select(customerCrateBalances).join([
      innerJoin(crateGroups, crateGroups.id.equalsExp(customerCrateBalances.crateGroupId)),
    ])..where(customerCrateBalances.customerId.equals(customerId)))
        .watch()
        .map((rows) {
          final Map<String, int> result = {};
          for (final row in rows) {
            final groupName = row.readTable(crateGroups).name;
            final balance = row.readTable(customerCrateBalances).balance;
            result[groupName] = balance;
          }
          return result;
        });
  }
}

@DriftAccessor(tables: [Purchases, PurchaseItems, Suppliers, Products, Inventory, StockAdjustments, ActivityLogs])
class DeliveriesDao extends DatabaseAccessor<AppDatabase> with _$DeliveriesDaoMixin {
  DeliveriesDao(super.db);

  Stream<List<DeliveryData>> watchAll() {
    return (select(attachedDatabase.purchases)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  Future<void> receiveDelivery(dynamic delivery, List<dynamic> items) async {
    return transaction(() async {
      // 1. Find or check supplier
      final supplier = await (select(attachedDatabase.suppliers)..where((t) => t.name.equals(delivery.supplierName))).getSingleOrNull();
      if (supplier == null) throw Exception("SupplierData ${delivery.supplierName} not found");

      // 2. Insert into purchases
      final purchaseId = await into(attachedDatabase.purchases).insert(PurchasesCompanion.insert(
        supplierId: supplier.id,
        totalAmountKobo: (delivery.totalValue * 100).toInt(),
        timestamp: Value(delivery.deliveredAt),
        status: 'pending',
      ));

      // 3. Insert items
      for (final item in items) {
        final prodId = int.tryParse(item.productId);
        if (prodId == null) throw Exception("Invalid product ID: ${item.productId}");

        await into(attachedDatabase.purchaseItems).insert(PurchaseItemsCompanion.insert(
          purchaseId: purchaseId,
          productId: prodId,
          quantity: item.quantity.toInt(),
          unitPriceKobo: (item.unitPrice * 100).toInt(),
          totalKobo: (item.lineTotal * 100).toInt(),
        ));
      }
    });
  }

  Future<void> confirmDelivery(String deliveryIdStr, String confirmedBy) async {
    final purchaseId = int.tryParse(deliveryIdStr);
    if (purchaseId == null) throw Exception("Invalid delivery ID: $deliveryIdStr");

    return transaction(() async {
      final purchase = await (select(attachedDatabase.purchases)..where((t) => t.id.equals(purchaseId))).getSingle();
      if (purchase.status == 'confirmed') return;

      // 1. Update status
      await (update(attachedDatabase.purchases)..where((t) => t.id.equals(purchaseId))).write(PurchasesCompanion(
        status: const Value('confirmed'),
      ));

      // 2. Get items and increment stock
      final items = await (select(attachedDatabase.purchaseItems)..where((t) => t.purchaseId.equals(purchaseId))).get();
      for (final item in items) {
        final inventoryItem = await (select(attachedDatabase.inventory)
              ..where((t) => t.productId.equals(item.productId) & t.warehouseId.equals(1)))
            .getSingleOrNull();

        if (inventoryItem != null) {
          await (update(attachedDatabase.inventory)..where((t) => t.id.equals(inventoryItem.id)))
              .write(InventoryCompanion(quantity: Value(inventoryItem.quantity + item.quantity)));
        } else {
          await into(attachedDatabase.inventory).insert(InventoryCompanion.insert(
            productId: item.productId,
            warehouseId: 1,
            quantity: Value(item.quantity),
          ));
        }

        // 3. Log stock adjustment
        await into(attachedDatabase.stockAdjustments).insert(StockAdjustmentsCompanion.insert(
          productId: item.productId,
          warehouseId: 1,
          quantityDiff: item.quantity,
          reason: "Delivery confirmed: $purchaseId",
          timestamp: Value(DateTime.now()),
        ));
      }

      // 4. Log activity
      await into(attachedDatabase.activityLogs).insert(ActivityLogsCompanion.insert(
        action: 'Confirmed Delivery #$purchaseId by $confirmedBy',
        description: 'Confirmed Delivery #$purchaseId by $confirmedBy',
        timestamp: Value(DateTime.now()),
      ));
    });
  }
}

@DriftAccessor(tables: [Expenses, ExpenseCategories])
class ExpensesDao extends DatabaseAccessor<AppDatabase> with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  Stream<List<ExpenseData>> watchAll() {
    return (select(attachedDatabase.expenses)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  Future<void> addExpense(ExpenseData expense) async {
    await into(attachedDatabase.expenses).insert(expense);
  }

  Stream<double> watchTotalThisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    final amountColumn = attachedDatabase.expenses.amountKobo.sum();
    final query = selectOnly(attachedDatabase.expenses)..addColumns([amountColumn]);
    query.where(attachedDatabase.expenses.timestamp.isBiggerOrEqualValue(startOfMonth));
    
    return query.watchSingle().map((row) {
      final sum = row.read(amountColumn);
      return (sum ?? 0).toDouble();
    });
  }
}

@DriftAccessor(tables: [SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  Future<List<SyncQueueData>> getPendingItems({int limit = 50}) {
    final now = DateTime.now();
    return (select(attachedDatabase.syncQueue)
          ..where((t) => t.isSynced.equals(false) & (t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now)))
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(limit))
        .get();
  }

  Future<void> markInProgress(int id) {
    return (update(attachedDatabase.syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(status: const Value('in_progress')),
    );
  }

  Future<void> markDone(int id) {
    return (update(attachedDatabase.syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(
        status: Value('done'),
        isSynced: Value(true),
      ),
    );
  }

  Future<void> markFailed(int id, String error, {bool permanent = false}) async {
    final entry = await (select(attachedDatabase.syncQueue)..where((t) => t.id.equals(id))).getSingle();
    final newAttempts = entry.attempts + 1;
    final isPermanent = permanent || newAttempts >= 5;

    final backoffSeconds = entry.attempts == 0 ? 0 : (1 << entry.attempts).clamp(0, 32);
    final nextAttempt = DateTime.now().add(Duration(seconds: backoffSeconds));

    await (update(attachedDatabase.syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        status: Value(isPermanent ? 'failed' : 'pending'),
        errorMessage: Value(error),
        attempts: Value(newAttempts),
        nextAttemptAt: isPermanent ? const Value(null) : Value(nextAttempt),
      ),
    );
  }

  Stream<int> watchPendingCount() {
    final count = attachedDatabase.syncQueue.id.count();
    final query = selectOnly(attachedDatabase.syncQueue)..addColumns([count]);
    query.where(attachedDatabase.syncQueue.status.equals('pending'));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> purgeOldDoneItems() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return (delete(attachedDatabase.syncQueue)
          ..where((t) => t.status.equals('done') & t.createdAt.isSmallerThanValue(thirtyDaysAgo)))
        .go();
  }
}

@DriftAccessor(tables: [ActivityLogs])
class ActivityLogDao extends DatabaseAccessor<AppDatabase> with _$ActivityLogDaoMixin {
  ActivityLogDao(super.db);

  Future<void> log({
    int? staffId,
    required String action,
    required String description,
    String? entityId,
    String? entityType,
    String? warehouseId,
  }) {
    return into(attachedDatabase.activityLogs).insert(
      ActivityLogsCompanion.insert(
        userId: Value(staffId),
        action: action,
        description: description,
        relatedEntityId: Value(entityId),
        relatedEntityType: Value(entityType),
        warehouseId: Value(warehouseId),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<ActivityLogData>> watchRecent({int limit = 100}) {
    return (select(attachedDatabase.activityLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }

  Future<List<ActivityLogData>> getForEntity(String entityId) {
    return (select(attachedDatabase.activityLogs)..where((t) => t.relatedEntityId.equals(entityId))).get();
  }
}

@DriftAccessor(tables: [Notifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase> with _$NotificationsDaoMixin {
  NotificationsDao(super.db);

  Future<void> create(String type, String message, {String? linkedRecordId}) {
    return into(attachedDatabase.notifications).insert(
      NotificationsCompanion.insert(
        type: type,
        message: message,
        linkedRecordId: Value(linkedRecordId),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<NotificationData>> watchAll() {
    return (select(attachedDatabase.notifications)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  Stream<int> watchUnreadCount() {
    final count = attachedDatabase.notifications.id.count();
    final query = selectOnly(attachedDatabase.notifications)..addColumns([count]);
    query.where(attachedDatabase.notifications.isRead.equals(false));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> markRead(int id) {
    return (update(attachedDatabase.notifications)..where((t) => t.id.equals(id))).write(
      const NotificationsCompanion(isRead: Value(true)),
    );
  }

  Future<void> markAllRead() {
    return (update(attachedDatabase.notifications)..where((t) => t.isRead.equals(false))).write(
      const NotificationsCompanion(isRead: Value(true)),
    );
  }
}
