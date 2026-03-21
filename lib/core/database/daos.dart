import 'dart:math';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'app_database.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Suppliers, Products, Categories, Warehouses, Manufacturers])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);
  Stream<List<SupplierData>> watchAllSupplierDatas() => select(suppliers).watch();
  Future<List<SupplierData>> getAllSuppliers() => select(suppliers).get();
  Future<int> insertSupplier(SuppliersCompanion companion) => into(suppliers).insert(companion);
  Future<int> insertProduct(ProductsCompanion companion) => into(products).insert(companion);

  /// Returns all manufacturers from the Manufacturers table.
  Future<List<ManufacturerData>> getAllManufacturers() => select(manufacturers).get();

  Stream<List<ProductData>> watchAvailableProductDatas({int? categoryId}) {
    if (categoryId != null) {
      return (select(products)..where((t) => t.isDeleted.not() & t.categoryId.equals(categoryId))).watch();
    }
    return (select(products)..where((t) => t.isDeleted.not())).watch();
  }
  Future<ProductData?> findById(int id) => (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<ProductData?> findByName(String name) => (select(products)..where((t) => t.name.lower().equals(name.toLowerCase()) & t.isDeleted.not())).getSingleOrNull();
  Future<void> softDeleteProduct(int productId) => (update(products)..where((t) => t.id.equals(productId))).write(const ProductsCompanion(isDeleted: Value(true)));

  Future<void> updateProductDetails(
    int productId, {
    required String name,
    String? manufacturer,
    int? manufacturerId,
    required int buyingPriceKobo,
    required int retailPriceKobo,
    int? bulkBreakerPriceKobo,
    int? distributorPriceKobo,
    int? emptyCrateValueKobo,
    int? categoryId,
  }) =>
      (update(products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          name: Value(name),
          manufacturer: Value(manufacturer),
          manufacturerId: Value(manufacturerId),
          sellingPriceKobo: Value(retailPriceKobo),
          buyingPriceKobo: Value(buyingPriceKobo),
          retailPriceKobo: Value(retailPriceKobo),
          bulkBreakerPriceKobo: Value(bulkBreakerPriceKobo),
          distributorPriceKobo: Value(distributorPriceKobo),
          emptyCrateValueKobo: Value(emptyCrateValueKobo ?? 0),
          categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
        ),
      );

  Future<void> updateMonthlyTarget(int productId, int targetUnits) =>
      (update(products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(monthlyTargetUnits: Value(targetUnits)),
      );

  int getPriceForCustomerGroup(ProductData product, String group) {
    switch (group) {
      case 'wholesaler':
        return product.distributorPriceKobo ?? product.retailPriceKobo;
      default:
        return product.retailPriceKobo;
    }
  }
}

@DriftAccessor(tables: [Products, Inventory, Warehouses, CrateGroups, Manufacturers, Categories])
class InventoryDao extends DatabaseAccessor<AppDatabase> with _$InventoryDaoMixin {
  InventoryDao(super.db);

  // ── Manufacturer CRUD ─────────────────────────────────────────────────────

  Stream<List<ManufacturerData>> watchAllManufacturers() =>
      (select(manufacturers)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<ManufacturerData>> getAllManufacturers() =>
      (select(manufacturers)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> insertManufacturer(ManufacturersCompanion companion) =>
      into(manufacturers).insert(companion);

  Future<void> updateManufacturerStock(int id, int newStock) =>
      (update(manufacturers)..where((t) => t.id.equals(id)))
          .write(ManufacturersCompanion(emptyCrateStock: Value(newStock)));

  Future<void> updateManufacturerDeposit(int id, int depositKobo) =>
      (update(manufacturers)..where((t) => t.id.equals(id)))
          .write(ManufacturersCompanion(depositAmountKobo: Value(depositKobo)));

  /// One-time snapshot of all products with their stock totals.
  /// Pass [warehouseId] to limit counts to a single warehouse (used by
  /// the warehouse-lock feature). Returns a plain [Future] — not a stream —
  /// so the data does not change while staff are entering count values.
  Future<List<ProductDataWithStock>> getProductsWithStock({int? warehouseId}) async {
    final qty = inventory.quantity.sum();
    final query = select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..where(products.isDeleted.not())
      ..groupBy([products.id])
      ..orderBy([OrderingTerm.asc(products.name)])
      ..addColumns([qty]);

    if (warehouseId != null) {
      query.where(inventory.warehouseId.equals(warehouseId));
    }

    final rows = await query.get();
    return rows
        .map((row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ))
        .toList();
  }

  // Returns a live stream of products filtered by category.
  // If categoryId is null, returns all categories (same as watchAllProductDatasWithStock).
  // The filtering happens inside the SQL query — only the matching rows
  // are sent to the app, which is much faster than loading everything
  // and filtering in Dart code.
  Stream<List<ProductDataWithStock>> watchProductsByCategory(int? categoryId) {
    final qty = inventory.quantity.sum();
    final query = select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..where(products.isDeleted.not())
      ..groupBy([products.id])
      ..addColumns([qty]);

    if (categoryId != null) {
      query.where(products.categoryId.equals(categoryId));
    }

    return query.watch().map((rows) => rows
        .map((row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ))
        .toList());
  }

  /// Live stream of products with stock totals for a single warehouse.
  Stream<List<ProductDataWithStock>> watchProductsByWarehouse(int warehouseId) {
    final qty = inventory.quantity.sum();
    final query = select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..where(products.isDeleted.not())
      ..where(inventory.warehouseId.equals(warehouseId))
      ..groupBy([products.id])
      ..addColumns([qty]);
    return query.watch().map((rows) => rows
        .map((row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ))
        .toList());
  }

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
    // innerJoin ensures only products that have an inventory record in this warehouse are returned.
    final query = select(products).join([
      innerJoin(
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
        .where((p) => p.totalStock > 0)
        .toList());
  }

  /// Streams the total quantity of empty-crate products (categoryId == 1) in a given warehouse.
  /// Pass null to sum across all warehouses.
  Stream<int> watchTotalEmptyCratesByWarehouse(int? warehouseId) {
    final qty = inventory.quantity.sum();
    if (warehouseId != null) {
      final query = selectOnly(products)
        ..join([
          innerJoin(
            inventory,
            inventory.productId.equalsExp(products.id) &
                inventory.warehouseId.equals(warehouseId),
          ),
        ])
        ..where(products.categoryId.equals(1) & products.isDeleted.not())
        ..addColumns([qty]);
      return query.watchSingleOrNull().map((row) => row?.read(qty) ?? 0);
    } else {
      final query = selectOnly(products)
        ..join([
          leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
        ])
        ..where(products.categoryId.equals(1) & products.isDeleted.not())
        ..addColumns([qty]);
      return query.watchSingleOrNull().map((row) => row?.read(qty) ?? 0);
    }
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

  Future<void> updateCrateGroupStock(int groupId, int newStock) =>
      (update(crateGroups)..where((t) => t.id.equals(groupId))).write(
        CrateGroupsCompanion(emptyCrateStock: Value(newStock)),
      );

  Future<void> updateCrateGroupDeposit(int groupId, int depositKobo) =>
      (update(crateGroups)..where((t) => t.id.equals(groupId))).write(
        CrateGroupsCompanion(depositAmountKobo: Value(depositKobo)),
      );

  /// Adds empty crates to a manufacturer's physical stock.
  Future<void> addEmptyCrates(int manufacturerId, int quantity) async {
    final row = await (select(manufacturers)..where((t) => t.id.equals(manufacturerId))).getSingleOrNull();
    if (row != null) {
      await (update(manufacturers)..where((t) => t.id.equals(manufacturerId)))
          .write(ManufacturersCompanion(emptyCrateStock: Value(row.emptyCrateStock + quantity)));
    }
  }

  /// Deducts empty crates from a manufacturer's physical stock (floors at 0).
  Future<void> deductEmptyCrates(int manufacturerId, int quantity) async {
    final row = await (select(manufacturers)..where((t) => t.id.equals(manufacturerId))).getSingleOrNull();
    if (row != null) {
      final newStock = (row.emptyCrateStock - quantity).clamp(0, 999999);
      await (update(manufacturers)..where((t) => t.id.equals(manufacturerId)))
          .write(ManufacturersCompanion(emptyCrateStock: Value(newStock)));
    }
  }

  /// Streams total glass bottle inventory per manufacturer for products in 'Glass' categories.
  /// Groups by manufacturer name for display in the 'Full Crates' column.
  Stream<Map<String, int>> watchFullCratesByManufacturer() {
    final qty = inventory.quantity.sum();
    final mfrName = manufacturers.name;
    final catName = categories.name;

    return (selectOnly(products)
      ..join([
        leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
        leftOuterJoin(manufacturers, manufacturers.id.equalsExp(products.manufacturerId)),
        leftOuterJoin(categories, categories.id.equalsExp(products.categoryId)),
      ])
      ..where(catName.like('%glass%') & 
              products.manufacturerId.isNotNull() &
              products.isDeleted.not())
      ..addColumns([mfrName, qty])
      ..groupBy([mfrName])
    ).watch().map((rows) {
      final result = <String, int>{};
      for (final row in rows) {
        final m = row.read(mfrName);
        if (m != null) result[m] = row.read(qty) ?? 0;
      }
      return result;
    });
  }

  /// Streams physical empty crates per manufacturer directly from the Manufacturers table.
  Stream<Map<String, int>> watchEmptyCratesByManufacturer() {
    return select(manufacturers).watch().map((list) =>
        {for (final m in list) m.name: m.emptyCrateStock});
  }

  /// Streams the sum of all empty crates across all manufacturers.
  Stream<int> watchTotalManufacturerEmptyCrates() {
    final qty = manufacturers.emptyCrateStock.sum();
    final query = selectOnly(manufacturers)..addColumns([qty]);
    return query.watchSingleOrNull().map((row) => row?.read(qty) ?? 0);
  }

  /// Streams the combined total of full crates (glass products in inventory) 
  /// and empty crates (physical stock in manufacturers table).
  Stream<int> watchTotalCrateAssets() {
    // 1. Watch total empty crates
    final emptyCratesStream = watchTotalManufacturerEmptyCrates();

    // 2. Watch total full crates (glass products)
    final qty = inventory.quantity.sum();
    final fullCratesStream = (selectOnly(products)
      ..join([
        leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
        leftOuterJoin(categories, categories.id.equalsExp(products.categoryId)),
      ])
      ..where(categories.name.like('%glass%') & products.isDeleted.not())
      ..addColumns([qty])
    ).watchSingleOrNull().map((row) => row?.read(qty) ?? 0);

    // Combine streams
    return Rx.combineLatest2<int, int, int>(
      emptyCratesStream,
      fullCratesStream,
      (a, b) => a + b,
    );
  }

  /// One-time snapshot: every (product, warehouse) pair sorted by warehouse
  /// name then product name. Suitable for the warehouse-grouped stock count UI.
  /// Pass [warehouseId] to restrict to a single warehouse.
  Future<List<ProductStockWithWarehouse>> getProductsStockPerWarehouse({int? warehouseId}) async {
    final query = select(products).join([
      innerJoin(inventory, inventory.productId.equalsExp(products.id)),
      innerJoin(warehouses, warehouses.id.equalsExp(inventory.warehouseId)),
    ])
      ..where(products.isDeleted.not())
      ..orderBy([
        OrderingTerm.asc(warehouses.name),
        OrderingTerm.asc(products.name),
      ]);
    if (warehouseId != null) {
      query.where(inventory.warehouseId.equals(warehouseId));
    }
    final rows = await query.get();
    return rows.map((row) => ProductStockWithWarehouse(
      warehouseId: row.readTable(warehouses).id,
      warehouseName: row.readTable(warehouses).name,
      product: row.readTable(products),
      totalStock: row.readTable(inventory).quantity,
    )).toList();
  }
}

class ProductDataWithStock {
  final ProductData product;
  final int totalStock;
  ProductDataWithStock({required this.product, required this.totalStock});
}

/// One (product, warehouse) row used by the warehouse-sorted stock count.
class ProductStockWithWarehouse {
  final int warehouseId;
  final String warehouseName;
  final ProductData product;
  final int totalStock;
  const ProductStockWithWarehouse({
    required this.warehouseId,
    required this.warehouseName,
    required this.product,
    required this.totalStock,
  });
}

class ManufacturerCrateStats {
  final String manufacturer;
  final int totalBottles;   // sum of inventory for big-crate products
  final int emptyCrates;    // sum of physical empty crates from linked crate groups
  final int totalValueKobo; // total monetary value of all crates (full & empty)

  ManufacturerCrateStats({
    required this.manufacturer,
    required this.totalBottles,
    required this.emptyCrates,
    required this.totalValueKobo,
  });

  // Raw bottle count — no longer dividing by 12.
  int get fullCratesEquiv => totalBottles;
  int get totalCrateAssets => totalBottles + emptyCrates;
}

@DriftAccessor(tables: [Orders, OrderItems, Products, Customers, SavedCarts, Categories])
class OrdersDao extends DatabaseAccessor<AppDatabase> with _$OrdersDaoMixin {
  OrdersDao(super.db);
  Stream<List<OrderData>> watchPendingOrders() => (select(orders)..where((t) => t.status.equals('pending'))).watch();
  Stream<List<OrderData>> watchAllOrders() => select(orders).watch();
  Stream<List<OrderData>> watchOrdersByWarehouse(int? warehouseId) => select(orders).watch();
  Stream<List<OrderWithItems>> watchAllOrdersWithItems() {
    return select(orders).watch().asyncMap((orderList) async {
      final result = <OrderWithItems>[];
      for (final order in orderList) {
        final itemRows = await (select(orderItems).join([
          innerJoin(products, products.id.equalsExp(orderItems.productId)),
        ])..where(orderItems.orderId.equals(order.id))).get();

        final itemsWithProducts = itemRows.map((row) => OrderItemDataWithProductData(
          row.readTable(orderItems),
          row.readTable(products),
        )).toList();

        CustomerData? customer;
        if (order.customerId != null) {
          customer = await (select(customers)..where((t) => t.id.equals(order.customerId!))).getSingleOrNull();
        }

        result.add(OrderWithItems(order, itemsWithProducts, customer));
      }
      return result;
    });
  }
  Stream<List<OrderData>> watchCompletedOrders() => (select(orders)..where((t) => t.status.equals('completed'))).watch();
  Stream<List<OrderData>> watchCancelledOrders() => (select(orders)..where((t) => t.status.equals('cancelled'))).watch();
  Future<void> markCompleted(int orderId, int staffId) async {
    await transaction(() async {
      // 1. Move order to completed
      await (update(orders)..where((t) => t.id.equals(orderId))).write(
        OrdersCompanion(
          status: const Value('completed'),
          completedAt: Value(DateTime.now()),
        ),
      );

      // 2. Deduct stock and add empty crates for every item in the order
      final items = await (select(orderItems)..where((t) => t.orderId.equals(orderId))).get();
      for (final item in items) {
        await db.inventoryDao.deductStock(item.productId, item.warehouseId, item.quantity);

        // Glass products: returning bottles creates empty crates for the manufacturer
        final productWithCat = await (select(products).join([
          leftOuterJoin(categories, categories.id.equalsExp(products.categoryId)),
        ])..where(products.id.equals(item.productId))).getSingleOrNull();

        final p = productWithCat?.readTable(products);
        final c = productWithCat?.readTableOrNull(categories);

        if (p?.manufacturerId != null && (c?.name.toLowerCase().contains('glass') == true)) {
          await db.inventoryDao.addEmptyCrates(p!.manufacturerId!, item.quantity);
        }
      }
    });
  }

  Future<void> markCancelled(int orderId, String reason, int staffId) async {
    await (update(orders)..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(
        status: const Value('cancelled'),
        cancelledAt: Value(DateTime.now()),
        cancellationReason: Value(reason),
      ),
    );
  }

  Future<void> assignRider(int orderId, String riderName) async {
    await (update(orders)..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(riderName: Value(riderName)),
    );
  }
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

  /// Returns units sold and revenue for this product today, this week, this month.
  Future<ProductSalesSummary> getSalesSummaryForProduct(int productId) async {
    final query = select(orderItems).join([
      innerJoin(orders, orders.id.equalsExp(orderItems.orderId)),
    ])
      ..where(orderItems.productId.equals(productId) & orders.status.equals('completed'));

    final rows = await query.get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);

    int todayUnits = 0, todayRevKobo = 0;
    int weekUnits = 0, weekRevKobo = 0;
    int monthUnits = 0, monthRevKobo = 0;

    for (final row in rows) {
      final item = row.readTable(orderItems);
      final order = row.readTable(orders);
      final date = order.createdAt;

      if (!date.isBefore(monthStart)) {
        monthUnits += item.quantity;
        monthRevKobo += item.totalKobo;
      }
      if (!date.isBefore(weekStart)) {
        weekUnits += item.quantity;
        weekRevKobo += item.totalKobo;
      }
      if (!date.isBefore(todayStart)) {
        todayUnits += item.quantity;
        todayRevKobo += item.totalKobo;
      }
    }

    return ProductSalesSummary(
      todayUnits: todayUnits,
      todayRevenueKobo: todayRevKobo,
      weekUnits: weekUnits,
      weekRevenueKobo: weekRevKobo,
      monthUnits: monthUnits,
      monthRevenueKobo: monthRevKobo,
    );
  }

  // ── Saved Carts ─────────────────────────────────────────────────────────

  Stream<List<SavedCartData>> watchSavedCarts() =>
      (select(savedCarts)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<int> saveCart(SavedCartsCompanion companion) => into(savedCarts).insert(companion);

  Future<void> deleteSavedCart(int id) => (delete(savedCarts)..where((t) => t.id.equals(id))).go();

  Future<SavedCartData?> getSavedCart(int id) =>
      (select(savedCarts)..where((t) => t.id.equals(id))).getSingleOrNull();
}

class ProductSalesSummary {
  final int todayUnits;
  final int todayRevenueKobo;
  final int weekUnits;
  final int weekRevenueKobo;
  final int monthUnits;
  final int monthRevenueKobo;

  const ProductSalesSummary({
    required this.todayUnits,
    required this.todayRevenueKobo,
    required this.weekUnits,
    required this.weekRevenueKobo,
    required this.monthUnits,
    required this.monthRevenueKobo,
  });

  factory ProductSalesSummary.empty() => const ProductSalesSummary(
        todayUnits: 0,
        todayRevenueKobo: 0,
        weekUnits: 0,
        weekRevenueKobo: 0,
        monthUnits: 0,
        monthRevenueKobo: 0,
      );
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
      leftOuterJoin(customerWallets, customerWallets.walletId.equalsExp(walletTransactions.walletId)),
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

  Future<void> updateCrateBalance(
    int customerId,
    int crateGroupId,
    int deltaQty,
  ) async {
    final existing = await (select(customerCrateBalances)
          ..where(
            (t) =>
                t.customerId.equals(customerId) &
                t.crateGroupId.equals(crateGroupId),
          ))
        .getSingleOrNull();

    if (existing != null) {
      final newBalance = existing.balance - deltaQty;
      await (update(customerCrateBalances)
            ..where(
              (t) =>
                  t.customerId.equals(customerId) &
                  t.crateGroupId.equals(crateGroupId),
            ))
          .write(CustomerCrateBalancesCompanion(balance: Value(newBalance)));
    } else {
      await into(customerCrateBalances).insert(
        CustomerCrateBalancesCompanion(
          customerId: Value(customerId),
          crateGroupId: Value(crateGroupId),
          balance: Value(-deltaQty),
        ),
      );
    }
  }

  Stream<Map<String, int>> watchCrateBalance(int customerId) => Stream.value({});

  Future<int> getWalletBalance(String walletId) async {
    final credits = walletTransactions.amountKobo.sum(filter: walletTransactions.type.equals('credit'));
    final debits = walletTransactions.amountKobo.sum(filter: walletTransactions.type.equals('debit'));

    final query = selectOnly(walletTransactions)
      ..addColumns([credits, debits])
      ..where(walletTransactions.walletId.equals(walletId));

    final row = await query.getSingleOrNull();
    if (row == null) return 0;
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

  /// Returns the most recent delivery (purchase) for a product, or null if none.
  Future<LastDeliveryInfo?> getLastDeliveryForProduct(int productId) async {
    final query = select(purchaseItems).join([
      innerJoin(purchases, purchases.id.equalsExp(purchaseItems.purchaseId)),
    ])
      ..where(purchaseItems.productId.equals(productId))
      ..orderBy([OrderingTerm.desc(purchases.timestamp)])
      ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final item = row.readTable(purchaseItems);
    final delivery = row.readTable(purchases);
    return LastDeliveryInfo(
      date: delivery.timestamp,
      quantity: item.quantity,
      unitPriceKobo: item.unitPriceKobo,
      totalKobo: item.totalKobo,
    );
  }
}

class LastDeliveryInfo {
  final DateTime date;
  final int quantity;
  final int unitPriceKobo;
  final int totalKobo;

  const LastDeliveryInfo({
    required this.date,
    required this.quantity,
    required this.unitPriceKobo,
    required this.totalKobo,
  });
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
  Future<List<ActivityLogData>> getStockCountLogs() => (select(activityLogs)..where((t) => t.action.equals('stock_count'))..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
}

@DriftAccessor(tables: [Users, Warehouses])
class WarehousesDao extends DatabaseAccessor<AppDatabase> with _$WarehousesDaoMixin {
  WarehousesDao(super.db);
  Stream<WarehouseData?> watchWarehouse(int id) => (select(warehouses)..where((t) => t.id.equals(id))).watchSingleOrNull();
  Future<WarehouseData?> getWarehouse(int id) => (select(warehouses)..where((t) => t.id.equals(id))).getSingleOrNull();
  Stream<List<UserData>> watchAllStaff() => select(users).watch();
  Future<List<UserData>> getRiders() => (select(users)..where((t) => t.role.equals('rider'))).get();
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
  Future<void> deleteSingle(int id) => (delete(notifications)..where((t) => t.id.equals(id))).go();
  Future<void> clearAll() => delete(notifications).go();
}

@DriftAccessor(tables: [StockTransactions, Products])
class StockLedgerDao extends DatabaseAccessor<AppDatabase> with _$StockLedgerDaoMixin {
  StockLedgerDao(super.db);
  
  Future<int> getCurrentStock(int productId, int locationId) async {
    final delta = stockTransactions.quantityDelta.sum();
    return await (selectOnly(stockTransactions)
          ..where(stockTransactions.productId.equals(productId))
          ..where(stockTransactions.locationId.equals(locationId))
          ..addColumns([delta]))
        .map((row) => row.read(delta) ?? 0)
        .getSingleOrNull() ?? 0;
  }

  Stream<int> watchCurrentStock(int productId, int locationId) {
    final delta = stockTransactions.quantityDelta.sum();
    return (selectOnly(stockTransactions)
          ..where(stockTransactions.productId.equals(productId))
          ..where(stockTransactions.locationId.equals(locationId))
          ..addColumns([delta]))
        .map((row) => row.read(delta) ?? 0)
        .watchSingleOrNull()
        .map((val) => val ?? 0);
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
      final transfer = await (select(stockTransfers)..where((t) => t.transferId.equals(transferId))).getSingleOrNull();
      if (transfer == null || (transfer.status != 'pending' && transfer.status != 'in_transit')) throw Exception('Transfer cannot be received');
      await (update(stockTransfers)..where((t) => t.transferId.equals(transferId))).write(StockTransfersCompanion(status: const Value('received'), receivedBy: Value(receivedBy), receivedAt: Value(DateTime.now())));
      await into(attachedDatabase.stockTransactions).insert(StockTransactionsCompanion.insert(transactionId: _generateUuid(), productId: transfer.productId, locationId: transfer.toLocationId, quantityDelta: transfer.quantity, movementType: 'transfer_in', referenceId: Value(transferId.toString()), performedBy: receivedBy, createdAt: Value(DateTime.now())));
    });
  }

  Future<void> cancelTransfer(int transferId) async {
    await transaction(() async {
      final transfer = await (select(stockTransfers)..where((t) => t.transferId.equals(transferId))).getSingleOrNull();
      if (transfer == null) throw Exception('Transfer not found');
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
