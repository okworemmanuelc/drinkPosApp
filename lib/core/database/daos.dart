import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/business_scoped_dao.dart';

part 'daos.g.dart';

@DriftAccessor(
  tables: [Suppliers, Products, Categories, Warehouses, Manufacturers],
)
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);
  Stream<List<SupplierData>> watchAllSupplierDatas() =>
      select(suppliers).watch();
  Future<List<SupplierData>> getAllSuppliers() => select(suppliers).get();
  Future<int> insertSupplier(SuppliersCompanion companion) =>
      into(suppliers).insert(companion);
  Future<int> insertProduct(ProductsCompanion companion) {
    return transaction(() async {
      final withSync = companion.copyWith(
        lastUpdatedAt: Value(DateTime.now()),
      );
      final id = await into(products).insert(withSync);
      final inserted = await findById(id);
      await db.syncDao.enqueue(
        'products:insert',
        jsonEncode({
          'id': inserted!.id,
          'business_id': inserted.businessId,
          'category_id': inserted.categoryId,
          'crate_group_id': inserted.crateGroupId,
          'size': inserted.size,
          'name': inserted.name,
          'subtitle': inserted.subtitle,
          'sku': inserted.sku,
          'retail_price_kobo': inserted.retailPriceKobo,
          'bulk_breaker_price_kobo': inserted.bulkBreakerPriceKobo,
          'distributor_price_kobo': inserted.distributorPriceKobo,
          'selling_price_kobo': inserted.sellingPriceKobo,
          'buying_price_kobo': inserted.buyingPriceKobo,
          'unit': inserted.unit,
          'icon_code_point': inserted.iconCodePoint,
          'color_hex': inserted.colorHex,
          'supplier_id': inserted.supplierId,
          'manufacturer_id': inserted.manufacturerId,
          'is_available': inserted.isAvailable,
          'is_deleted': inserted.isDeleted,
          'low_stock_threshold': inserted.lowStockThreshold,
          'manufacturer': inserted.manufacturer,
          'avg_daily_sales': inserted.avgDailySales,
          'lead_time_days': inserted.leadTimeDays,
          'safety_stock_qty': inserted.safetyStockQty,
          'monthly_target_units': inserted.monthlyTargetUnits,
          'empty_crate_value_kobo': inserted.emptyCrateValueKobo,
          'track_empties': inserted.trackEmpties,
          'image_path': inserted.imagePath,
          'last_updated_at': inserted.lastUpdatedAt?.toIso8601String(),
        }),
        businessId: inserted.businessId ?? db.currentBusinessId!,
      );
      return id;
    });
  }

  /// Returns all manufacturers from the Manufacturers table.
  Future<List<ManufacturerData>> getAllManufacturers() =>
      select(manufacturers).get();

  Stream<List<ProductData>> watchAvailableProductDatas({int? categoryId}) {
    if (categoryId != null) {
      return (select(products)
            ..where((t) => t.isDeleted.not() & t.categoryId.equals(categoryId)))
          .watch();
    }
    return (select(products)..where((t) => t.isDeleted.not())).watch();
  }

  Future<ProductData?> findById(int id) =>
      (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<ProductData?> findByName(String name) =>
      (select(products)..where(
            (t) =>
                t.name.lower().equals(name.toLowerCase()) & t.isDeleted.not(),
          ))
          .getSingleOrNull();
  Future<void> softDeleteProduct(int productId) async {
    await transaction(() async {
      await (update(products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          isDeleted: const Value(true),
          lastUpdatedAt: Value(DateTime.now()),
        ),
      );
      final product = await findById(productId);
      await db.syncDao.enqueue(
        'products:update',
        jsonEncode({
          'id': productId,
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        }),
        businessId: product?.businessId ?? db.currentBusinessId!,
      );
    });
  }

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
    String? unit,
    bool? trackEmpties,
    int? lowStockThreshold,
    String? imagePath,
  }) => (update(products)..where((t) => t.id.equals(productId))).write(
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
      unit: unit != null ? Value(unit) : const Value.absent(),
      trackEmpties: trackEmpties != null
          ? Value(trackEmpties)
          : const Value.absent(),
      lowStockThreshold: lowStockThreshold != null
          ? Value(lowStockThreshold)
          : const Value.absent(),
      imagePath: imagePath != null ? Value(imagePath) : const Value.absent(),
    ),
  );

  /// Returns unique unit values found in the products table.
  Future<List<String>> getUniqueProductUnits() async {
    final query = selectOnly(products, distinct: true)
      ..addColumns([products.unit]);
    final rows = await query.get();
    return rows
        .map((row) => row.read(products.unit))
        .whereType<String>()
        .toList();
  }

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

  /// Bulk updates the empty crate value for all products of a manufacturer.
  Future<void> updateManufacturerEmptyCrateValue(
    int manufacturerId,
    int valueKobo,
  ) => (update(products)..where((t) => t.manufacturerId.equals(manufacturerId)))
      .write(ProductsCompanion(emptyCrateValueKobo: Value(valueKobo)));

  /// Toggles empty-crate tracking for a single product.
  Future<void> updateTrackEmpties(int productId, bool value) =>
      (update(products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(trackEmpties: Value(value)),
      );
}

@DriftAccessor(
  tables: [
    Products,
    Inventory,
    Warehouses,
    CrateGroups,
    Manufacturers,
    Categories,
  ],
)
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin, BusinessScopedDao<AppDatabase> {
  InventoryDao(super.db);

  // ── Manufacturer CRUD ─────────────────────────────────────────────────────

  Stream<List<ManufacturerData>> watchAllManufacturers() => (select(
    manufacturers,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<ManufacturerData>> getAllManufacturers() =>
      (select(manufacturers)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> insertManufacturer(ManufacturersCompanion companion) =>
      into(manufacturers).insert(companion);

  Future<void> updateManufacturerStock(int id, int newStock) =>
      (update(manufacturers)..where((t) => t.id.equals(id))).write(
        ManufacturersCompanion(emptyCrateStock: Value(newStock)),
      );

  Future<void> updateManufacturerDeposit(int id, int depositKobo) =>
      (update(manufacturers)..where((t) => t.id.equals(id))).write(
        ManufacturersCompanion(depositAmountKobo: Value(depositKobo)),
      );

  /// One-time snapshot of all products with their stock totals.
  /// Pass [warehouseId] to limit counts to a single warehouse (used by
  /// the warehouse-lock feature). Returns a plain [Future] — not a stream —
  /// so the data does not change while staff are entering count values.
  Future<List<ProductDataWithStock>> getProductsWithStock({
    int? warehouseId,
  }) async {
    final qty = inventory.quantity.sum();
    final query =
        select(products).join([
            leftOuterJoin(
              inventory,
              inventory.productId.equalsExp(products.id),
            ),
          ])
          ..where(products.isDeleted.not() &
              products.businessId.equals(requireBusinessId()))
          ..groupBy([products.id])
          ..orderBy([OrderingTerm.asc(products.name)])
          ..addColumns([qty]);

    if (warehouseId != null) {
      query.where(inventory.warehouseId.equals(warehouseId));
    }

    final rows = await query.get();
    return rows
        .map(
          (row) => ProductDataWithStock(
            product: row.readTable(products),
            totalStock: row.read(qty) ?? 0,
          ),
        )
        .toList();
  }

  // Returns a live stream of products filtered by category.
  // If categoryId is null, returns all categories (same as watchAllProductDatasWithStock).
  // The filtering happens inside the SQL query — only the matching rows
  // are sent to the app, which is much faster than loading everything
  // and filtering in Dart code.
  Stream<List<ProductDataWithStock>> watchProductsByCategory(int? categoryId) {
    final qty = inventory.quantity.sum();
    final query =
        select(products).join([
            leftOuterJoin(
              inventory,
              inventory.productId.equalsExp(products.id),
            ),
          ])
          ..where(products.isDeleted.not() &
              products.businessId.equals(requireBusinessId()))
          ..groupBy([products.id])
          ..addColumns([qty]);

    if (categoryId != null) {
      query.where(products.categoryId.equals(categoryId));
    }

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Live stream of products with stock totals for a single warehouse.
  Stream<List<ProductDataWithStock>> watchProductsByWarehouse(int warehouseId) {
    final qty = inventory.quantity.sum();
    final query =
        select(products).join([
            leftOuterJoin(
              inventory,
              inventory.productId.equalsExp(products.id),
            ),
          ])
          ..where(products.isDeleted.not() &
              products.businessId.equals(requireBusinessId()))
          ..where(inventory.warehouseId.equals(warehouseId))
          ..groupBy([products.id])
          ..addColumns([qty]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Stream<List<ProductDataWithStock>> watchAllProductDatasWithStock() {
    final qty = inventory.quantity.sum();
    final query =
        select(products).join([
            leftOuterJoin(
              inventory,
              inventory.productId.equalsExp(products.id),
            ),
          ])
          ..where(products.isDeleted.not() &
              products.businessId.equals(requireBusinessId()))
          ..groupBy([products.id])
          ..addColumns([qty]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Stream<List<ProductDataWithStock>> watchLowStockProductDatas() {
    final qty = inventory.quantity.sum();
    final query =
        select(products).join([
            leftOuterJoin(
              inventory,
              inventory.productId.equalsExp(products.id),
            ),
          ])
          ..where(products.isDeleted.not() &
              products.businessId.equals(requireBusinessId()))
          ..groupBy([products.id])
          ..addColumns([qty]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ),
          )
          .where(
            (p) =>
                p.totalStock > 0 && p.totalStock <= p.product.lowStockThreshold,
          )
          .toList(),
    );
  }

  Stream<List<ProductDataWithStock>> watchProductDatasWithStockByWarehouse(
    int warehouseId,
  ) {
    final qty = inventory.quantity.sum();
    // innerJoin ensures only products that have an inventory record in this warehouse are returned.
    final query =
        select(products).join([
            innerJoin(
              inventory,
              inventory.productId.equalsExp(products.id) &
                  inventory.warehouseId.equals(warehouseId),
            ),
          ])
          ..where(products.isDeleted.not() &
              products.businessId.equals(requireBusinessId()))
          ..groupBy([products.id])
          ..addColumns([qty]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ProductDataWithStock(
              product: row.readTable(products),
              totalStock: row.read(qty) ?? 0,
            ),
          )
          .toList(),
    );
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
        ..where(products.categoryId.equals(1) &
            products.isDeleted.not() &
            products.businessId.equals(requireBusinessId()))
        ..addColumns([qty]);
      return query.watchSingleOrNull().map((row) => row?.read(qty) ?? 0);
    } else {
      final query = selectOnly(products)
        ..join([
          leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
        ])
        ..where(products.categoryId.equals(1) &
            products.isDeleted.not() &
            products.businessId.equals(requireBusinessId()))
        ..addColumns([qty]);
      return query.watchSingleOrNull().map((row) => row?.read(qty) ?? 0);
    }
  }

  Future<void> deductStock(int productId, int warehouseId, int qty) async {
    await transaction(() async {
      final row =
          await (select(inventory)..where(
                (t) =>
                    t.productId.equals(productId) &
                    t.warehouseId.equals(warehouseId),
              ))
              .getSingleOrNull();
      if (row != null) {
        final newQty = (row.quantity - qty).clamp(0, 999999);
        await (update(inventory)..where((t) => t.id.equals(row.id))).write(
          InventoryCompanion(quantity: Value(newQty)),
        );
      }
    });
  }

  Future<void> adjustStock(
    int productId,
    int warehouseId,
    int delta,
    String note,
    int? staffId,
  ) async {
    await transaction(() async {
      final existing =
          await (select(inventory)..where(
                (t) =>
                    t.productId.equals(productId) &
                    t.warehouseId.equals(warehouseId),
              ))
              .getSingleOrNull();
      if (existing != null) {
        final newQty = (existing.quantity + delta).clamp(0, 999999);
        await (update(inventory)..where((t) => t.id.equals(existing.id))).write(
          InventoryCompanion(quantity: Value(newQty)),
        );
      } else if (delta > 0) {
        await into(inventory).insert(
          InventoryCompanion.insert(
            productId: productId,
            warehouseId: warehouseId,
            quantity: Value(delta),
          ),
        );
      }

      // Record in stock ledger for audit trail
      await db.stockLedgerDao.insertTransaction(
        StockTransactionsCompanion.insert(
          transactionId:
              '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(10000)}',
          productId: productId,
          locationId: warehouseId,
          quantityDelta: delta,
          movementType: 'adjustment',
          referenceId: Value(note),
          performedBy: staffId ?? 0,
          createdAt: Value(DateTime.now()),
        ),
      );

      // Queue for Sync
      final product = await (select(db.products)..where((t) => t.id.equals(productId))).getSingleOrNull();
      await db.syncDao.enqueue(
        'stock_adjustments:insert',
        jsonEncode({
          'business_id': product?.businessId,
          'product_id': productId,
          'warehouse_id': warehouseId,
          'quantity_diff': delta,
          'reason': note,
          'timestamp': DateTime.now().toIso8601String(),
          'last_updated_at': DateTime.now().toIso8601String(),
        }),
        businessId: product?.businessId ?? db.currentBusinessId!,
      );
    });
  }

  Stream<List<CategoryData>> watchAllCategories() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<CrateGroupData>> watchAllCrateGroups() =>
      select(crateGroups).watch();
  Future<List<CrateGroupData>> getAllCrateGroups() => select(crateGroups).get();

  Future<void> assignCrateGroup(
    int productId,
    int? crateGroupId,
    String? size,
  ) async {
    await (update(products)..where((t) => t.id.equals(productId))).write(
      ProductsCompanion(crateGroupId: Value(crateGroupId), size: Value(size)),
    );
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
    await transaction(() async {
      final row = await (select(
        manufacturers,
      )..where((t) => t.id.equals(manufacturerId))).getSingleOrNull();
      if (row != null) {
        await (update(
          manufacturers,
        )..where((t) => t.id.equals(manufacturerId))).write(
          ManufacturersCompanion(
            emptyCrateStock: Value(row.emptyCrateStock + quantity),
          ),
        );
      }
    });
  }

  /// Deducts empty crates from a manufacturer's physical stock (floors at 0).
  Future<void> deductEmptyCrates(int manufacturerId, int quantity) async {
    await transaction(() async {
      final row = await (select(
        manufacturers,
      )..where((t) => t.id.equals(manufacturerId))).getSingleOrNull();
      if (row != null) {
        final newStock = (row.emptyCrateStock - quantity).clamp(0, 999999);
        await (update(manufacturers)..where((t) => t.id.equals(manufacturerId)))
            .write(ManufacturersCompanion(emptyCrateStock: Value(newStock)));
      }
    });
  }

  /// Streams total crate bottle inventory per manufacturer for products with crate sizes.
  /// Groups by manufacturer name for display in the 'Full Crates' column.
  Stream<Map<String, int>> watchFullCratesByManufacturer() {
    final qty = inventory.quantity.sum();
    final mfrName = manufacturers.name;

    return (selectOnly(products)
          ..join([
            leftOuterJoin(
              inventory,
              inventory.productId.equalsExp(products.id),
            ),
            leftOuterJoin(
              manufacturers,
              manufacturers.id.equalsExp(products.manufacturerId),
            ),
            leftOuterJoin(
              categories,
              categories.id.equalsExp(products.categoryId),
            ),
          ])
          ..where(
            products.size.isNotNull() &
                products.manufacturerId.isNotNull() &
                products.isDeleted.not() &
                products.businessId.equals(requireBusinessId()),
          )
          ..addColumns([mfrName, qty])
          ..groupBy([mfrName]))
        .watch()
        .map((rows) {
          final result = <String, int>{};
          for (final row in rows) {
            final m = row.read(mfrName);
            if (m != null) result[m] = row.read(qty) ?? 0;
          }
          return result;
        });
  }

  Stream<Map<String, int>> watchEmptyCratesByManufacturer() {
    return (select(manufacturers)
          ..where((t) => t.businessId.equals(requireBusinessId())))
        .watch()
        .map((list) => {for (final m in list) m.name: m.emptyCrateStock});
  }

  /// Streams the sum of all empty crates across all manufacturers.
  Stream<int> watchTotalManufacturerEmptyCrates() {
    final qty = manufacturers.emptyCrateStock.sum();
    final query = selectOnly(manufacturers)
      ..where(manufacturers.businessId.equals(requireBusinessId()))
      ..addColumns([qty]);
    return query.watchSingleOrNull().map((row) => row?.read(qty) ?? 0);
  }

  /// Streams the combined total of full crates (products with size in inventory)
  /// and empty crates (physical stock in manufacturers table).
  Stream<int> watchTotalCrateAssets() {
    // 1. Watch total empty crates
    final emptyCratesStream = watchTotalManufacturerEmptyCrates();

    // 2. Watch total full crates (products with sizes)
    final qty = inventory.quantity.sum();
    final fullCratesStream =
        (selectOnly(products)
              ..join([
                leftOuterJoin(
                  inventory,
                  inventory.productId.equalsExp(products.id),
                ),
                leftOuterJoin(
                  categories,
                  categories.id.equalsExp(products.categoryId),
                ),
              ])
              ..where(products.size.isNotNull() &
                  products.isDeleted.not() &
                  products.businessId.equals(requireBusinessId()))
              ..addColumns([qty]))
            .watchSingleOrNull()
            .map((row) => row?.read(qty) ?? 0);

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
  Future<List<ProductStockWithWarehouse>> getProductsStockPerWarehouse({
    int? warehouseId,
  }) async {
    final query =
        select(products).join([
            innerJoin(inventory, inventory.productId.equalsExp(products.id)),
            innerJoin(
              warehouses,
              warehouses.id.equalsExp(inventory.warehouseId),
            ),
          ])
          ..where(products.isDeleted.not() &
              products.businessId.equals(requireBusinessId()))
          ..orderBy([
            OrderingTerm.asc(warehouses.name),
            OrderingTerm.asc(products.name),
          ]);
    if (warehouseId != null) {
      query.where(inventory.warehouseId.equals(warehouseId));
    }
    final rows = await query.get();
    return rows
        .map(
          (row) => ProductStockWithWarehouse(
            warehouseId: row.readTable(warehouses).id,
            warehouseName: row.readTable(warehouses).name,
            product: row.readTable(products),
            totalStock: row.readTable(inventory).quantity,
          ),
        )
        .toList();
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
  final int totalBottles; // sum of inventory for big-crate products
  final int
  emptyCrates; // sum of physical empty crates from linked crate groups
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

@DriftAccessor(
  tables: [Orders, OrderItems, Products, Customers, SavedCarts, Categories],
)
class OrdersDao extends DatabaseAccessor<AppDatabase> with _$OrdersDaoMixin {
  OrdersDao(super.db);
  Future<OrderData?> findById(int id) =>
      (select(orders)..where((t) => t.id.equals(id))).getSingleOrNull();
  Stream<List<OrderData>> watchPendingOrders() =>
      (select(orders)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();
  Stream<List<OrderData>> watchAllOrders() => (select(
    orders,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  Stream<List<OrderData>> watchOrdersByWarehouse(int? warehouseId) {
    if (warehouseId == null) {
      return (select(
        orders,
      )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
    }
    return (select(orders)
          ..where((t) => t.warehouseId.equals(warehouseId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<OrderWithItems>> watchAllOrdersWithItems({int? warehouseId}) {
    final query = select(orders)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (warehouseId != null) {
      query.where((t) => t.warehouseId.equals(warehouseId));
    }
    return query.watch().asyncMap((orderList) async {
      final result = <OrderWithItems>[];
      for (final order in orderList) {
        final itemRows = await (select(orderItems).join([
          innerJoin(products, products.id.equalsExp(orderItems.productId)),
        ])..where(orderItems.orderId.equals(order.id))).get();

        final itemsWithProducts = itemRows
            .map(
              (row) => OrderItemDataWithProductData(
                row.readTable(orderItems),
                row.readTable(products),
              ),
            )
            .toList();

        CustomerData? customer;
        if (order.customerId != null) {
          customer = await (select(
            customers,
          )..where((t) => t.id.equals(order.customerId!))).getSingleOrNull();
        }

        result.add(OrderWithItems(order, itemsWithProducts, customer));
      }
      return result;
    });
  }

  Stream<List<OrderData>> watchCompletedOrders() =>
      (select(orders)
            ..where((t) => t.status.equals('completed'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();
  Stream<List<OrderData>> watchCancelledOrders() =>
      (select(orders)
            ..where((t) => t.status.equals('cancelled'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();
  Stream<List<OrderData>> watchOrdersByCustomer(int customerId) =>
      (select(orders)
            ..where((t) => t.customerId.equals(customerId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();
  Future<void> markCompleted(int orderId, int staffId) async {
    await transaction(() async {
      // 1. Move order to completed
      await (update(orders)..where((t) => t.id.equals(orderId))).write(
        OrdersCompanion(
          status: const Value('completed'),
          completedAt: Value(DateTime.now()),
        ),
      );

      // 2. Deduct stock for every item in the order.
      // Empty-crate accounting is handled by `CrateReturnModal._confirm()`
      // before this method is called, so we no longer add empty crates here
      // (doing so would double-count).
      final items = await (select(
        orderItems,
      )..where((t) => t.orderId.equals(orderId))).get();
      final now = DateTime.now();
      for (final item in items) {
        await db.inventoryDao.deductStock(
          item.productId,
          item.warehouseId,
          item.quantity,
        );

        // Record sale in stock ledger for audit trail
        await db.stockLedgerDao.insertTransaction(
          StockTransactionsCompanion.insert(
            transactionId:
                '${now.microsecondsSinceEpoch}-${Random().nextInt(10000)}-${item.productId}',
            productId: item.productId,
            locationId: item.warehouseId,
            quantityDelta: -item.quantity,
            movementType: 'sale',
            referenceId: Value(orderId.toString()),
            performedBy: staffId,
            createdAt: Value(now),
          ),
        );
      }
    });
  }

  Future<void> markCancelled(int orderId, String reason, int staffId) async {
    await transaction(() async {
      // Check if the order was completed (stock already deducted)
      final order = await (select(orders)
            ..where((t) => t.id.equals(orderId)))
          .getSingleOrNull();

      await (update(orders)..where((t) => t.id.equals(orderId))).write(
        OrdersCompanion(
          status: const Value('cancelled'),
          cancelledAt: Value(DateTime.now()),
          cancellationReason: Value(reason),
        ),
      );

      // If order was completed, reverse stock deductions and record returns
      if (order != null && order.status == 'completed') {
        final items = await (select(orderItems)
              ..where((t) => t.orderId.equals(orderId)))
            .get();
        final now = DateTime.now();
        for (final item in items) {
          // Add stock back (direct inventory update — not adjustStock, to
          // avoid generating a duplicate 'adjustment' ledger entry)
          final existing = await (select(db.inventory)
                ..where((t) =>
                    t.productId.equals(item.productId) &
                    t.warehouseId.equals(item.warehouseId)))
              .getSingleOrNull();
          if (existing != null) {
            final newQty =
                (existing.quantity + item.quantity).clamp(0, 999999);
            await (update(db.inventory)
                  ..where((t) => t.id.equals(existing.id)))
                .write(InventoryCompanion(quantity: Value(newQty)));
          } else {
            await into(db.inventory).insert(
              InventoryCompanion.insert(
                productId: item.productId,
                warehouseId: item.warehouseId,
                quantity: Value(item.quantity),
              ),
            );
          }

          // Record return in stock ledger
          await db.stockLedgerDao.insertTransaction(
            StockTransactionsCompanion.insert(
              transactionId:
                  '${now.microsecondsSinceEpoch}-${Random().nextInt(10000)}-ret-${item.productId}',
              productId: item.productId,
              locationId: item.warehouseId,
              quantityDelta: item.quantity,
              movementType: 'return',
              referenceId: Value(orderId.toString()),
              performedBy: staffId,
              createdAt: Value(now),
            ),
          );
        }
      }
    });
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

      // Get businessId from staff
      final staff = await db.warehousesDao.getUserById(staffId);
      final businessId = staff?.businessId;

      final orderWithSync = order.copyWith(
        orderNumber: Value(orderNo),
        businessId: Value(businessId),
        lastUpdatedAt: Value(DateTime.now()),
        // If customerId is -1 (Walk-in), store as null in DB to avoid FK issues
        // and ensure watchAllOrdersWithItems works correctly.
        customerId: (order.customerId.value == -1)
            ? const Value(null)
            : order.customerId,
      );

      // 2. Insert Order
      final orderId = await into(orders).insert(orderWithSync);

      // 3. Insert Items
      for (final item in items) {
        await into(orderItems).insert(item.copyWith(
          orderId: Value(orderId),
          businessId: Value(businessId),
          lastUpdatedAt: Value(DateTime.now()),
        ));
      }

      // 4. Queue for Sync
      final insertedOrder = await (select(orders)..where((t) => t.id.equals(orderId))).getSingleOrNull();
      await db.syncDao.enqueue(
        'orders:insert',
        jsonEncode({
          'id': orderId,
          'business_id': businessId,
          'order_number': orderNo,
          'customer_id': insertedOrder?.customerId,
          'total_amount_kobo': insertedOrder?.totalAmountKobo,
          'discount_kobo': insertedOrder?.discountKobo,
          'net_amount_kobo': insertedOrder?.netAmountKobo,
          'amount_paid_kobo': insertedOrder?.amountPaidKobo,
          'payment_type': insertedOrder?.paymentType,
          'created_at': insertedOrder?.createdAt.toIso8601String(),
          'status': insertedOrder?.status,
          'rider_name': insertedOrder?.riderName,
          'cancellation_reason': insertedOrder?.cancellationReason,
          'barcode': insertedOrder?.barcode,
          'staff_id': staffId,
          'warehouse_id': insertedOrder?.warehouseId,
          'crate_deposit_paid_kobo': insertedOrder?.crateDepositPaidKobo,
          'last_updated_at': insertedOrder?.lastUpdatedAt?.toIso8601String(),
        }),
        businessId: businessId ?? db.currentBusinessId!,
      );

      // 5. Queue line items for Sync (cloud `order_items` is a separate table
      // with FK to orders, so each row needs its own upsert).
      final insertedItems = await (select(orderItems)
            ..where((t) => t.orderId.equals(orderId)))
          .get();
      for (final it in insertedItems) {
        await db.syncDao.enqueue(
          'order_items:insert',
          jsonEncode({
            'id': it.id,
            'business_id': it.businessId,
            'order_id': it.orderId,
            'product_id': it.productId,
            'warehouse_id': it.warehouseId,
            'quantity': it.quantity,
            'unit_price_kobo': it.unitPriceKobo,
            'buying_price_kobo': it.buyingPriceKobo,
            'total_kobo': it.totalKobo,
            'last_updated_at': it.lastUpdatedAt?.toIso8601String(),
          }),
          businessId: it.businessId ?? businessId ?? db.currentBusinessId!,
        );
      }

      // Wallet transactions are handled by OrderService._recordWalletTransactions()

      return orderNo;
    });
  }

  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final datePart = DateFormat('yyMMddHHmmss').format(now); // 12 digits
    final randomPart = (Random().nextInt(9000) + 1000)
        .toString(); // 4 digits (ensuring 4 digits)
    return '$datePart$randomPart';
  }

  /// Returns units sold and revenue for this product today, this week, this month.
  Future<ProductSalesSummary> getSalesSummaryForProduct(int productId) async {
    final query =
        select(orderItems).join([
          innerJoin(orders, orders.id.equalsExp(orderItems.orderId)),
        ])..where(
          orderItems.productId.equals(productId) &
              orders.status.equals('completed'),
        );

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

  Stream<List<SavedCartData>> watchSavedCarts() => (select(
    savedCarts,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<int> saveCart(SavedCartsCompanion companion) =>
      into(savedCarts).insert(companion);

  Future<void> deleteSavedCart(int id) =>
      (delete(savedCarts)..where((t) => t.id.equals(id))).go();

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

class CrateBalanceEntry {
  final int crateGroupId;
  final String groupName;
  final int balance;
  CrateBalanceEntry({
    required this.crateGroupId,
    required this.groupName,
    required this.balance,
  });
}

@DriftAccessor(
  tables: [
    Customers,
    CustomerWalletTransactions,
    CustomerCrateBalances,
    CustomerWallets,
    WalletTransactions,
    CrateGroups,
  ],
)
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);
  Stream<List<CustomerData>> watchAllCustomers() =>
      (select(customers)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();
  Stream<List<CustomerData>> watchCustomersByWarehouse(int warehouseId) =>
      (select(customers)
            ..where((t) => t.warehouseId.equals(warehouseId))
            ..orderBy([(t) => OrderingTerm.desc(t.id)]))
          .watch();
  Future<CustomerData?> findById(int id) =>
      (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<CustomerData?> findByPhone(String phone) => (select(
    customers,
  )..where((t) => t.phone.equals(phone))).getSingleOrNull();
  Stream<CustomerData?> watchCustomerById(int id) =>
      (select(customers)..where((t) => t.id.equals(id))).watchSingleOrNull();
  Stream<List<CrateBalanceEntry>> watchCrateBalancesWithGroups(int customerId) {
    final query = select(customerCrateBalances).join([
      innerJoin(
        crateGroups,
        crateGroups.id.equalsExp(customerCrateBalances.crateGroupId),
      ),
    ])..where(customerCrateBalances.customerId.equals(customerId));
    return query.watch().map(
      (rows) => rows.map((row) {
        final b = row.readTable(customerCrateBalances);
        final g = row.readTable(crateGroups);
        return CrateBalanceEntry(
          crateGroupId: g.id,
          groupName: g.name,
          balance: b.balance,
        );
      }).toList(),
    );
  }

  Future<int> addCustomer(CustomersCompanion customer) async {
    return transaction(() async {
      final customerWithSync = customer.copyWith(
        lastUpdatedAt: Value(DateTime.now()),
      );
      final customerId = await into(customers).insert(customerWithSync);

      // Every customer must have a wallet. The wallet inherits business_id
      // from the customer so cloud RLS / FK accept the row.
      final walletId = _generateUuid();
      await into(customerWallets).insert(
        CustomerWalletsCompanion.insert(
          walletId: walletId,
          customerId: customerId,
          businessId: customer.businessId,
          lastUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Queue for Sync
      final data = await findById(customerId);
      await db.syncDao.enqueue(
        'customers:insert',
        jsonEncode(_customerPayload(data!)),
        businessId: data.businessId ?? db.currentBusinessId!,
      );

      final wallet = await (select(customerWallets)
            ..where((t) => t.walletId.equals(walletId)))
          .getSingle();
      await db.syncDao.enqueue(
        // wallet_id (TEXT) is the cloud PK — no `id` column exists.
        'customer_wallets:upsert:wallet_id',
        jsonEncode({
          'wallet_id': wallet.walletId,
          'business_id': wallet.businessId,
          'customer_id': wallet.customerId,
          'currency': wallet.currency,
          'created_at': wallet.createdAt.toIso8601String(),
          'is_active': wallet.isActive,
          'is_deleted': wallet.isDeleted,
          'last_updated_at': wallet.lastUpdatedAt?.toIso8601String(),
        }),
        businessId: wallet.businessId ?? db.currentBusinessId!,
      );

      return customerId;
    });
  }

  /// Shared payload shape for both `customers:insert` and `customers:update`.
  Map<String, dynamic> _customerPayload(CustomerData data) => {
        'id': data.id,
        'business_id': data.businessId,
        'warehouse_id': data.warehouseId,
        'name': data.name,
        'phone': data.phone,
        'email': data.email,
        'address': data.address,
        'google_maps_location': data.googleMapsLocation,
        'customer_group': data.customerGroup,
        'created_at': data.createdAt.toIso8601String(),
        'wallet_balance_kobo': data.walletBalanceKobo,
        'wallet_limit_kobo': data.walletLimitKobo,
        'last_updated_at': data.lastUpdatedAt?.toIso8601String(),
        'is_deleted': data.isDeleted,
      };

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return 'wlt-$random'; // Simple unique wallet ID
  }

  Future<void> updateWalletBalance({
    required int customerId,
    required int amountKobo,
    required String type, // credit or debit
    required String referenceType,
    String? referenceId,
    required int staffId,
    String? note,
  }) async {
    return transaction(() async {
      final wallet = await (select(
        customerWallets,
      )..where((t) => t.customerId.equals(customerId))).getSingleOrNull();

      if (wallet == null) throw Exception('Customer wallet not found');

      final now = DateTime.now();

      // 1. Update the cached balance on the Customers row for quick access
      final customer = await findById(customerId);
      if (customer != null) {
        final newBalance =
            customer.walletBalanceKobo +
            (type == 'credit' ? amountKobo : -amountKobo);
        await (update(customers)..where((t) => t.id.equals(customerId))).write(
          CustomersCompanion(
            walletBalanceKobo: Value(newBalance),
            lastUpdatedAt: Value(now),
          ),
        );
      }

      // 2. Insert into WalletTransactions for audit trail
      // referenceId encodes type + referenceId to avoid timestamp collisions when
      // two entries are created for the same order (Full Cash, Partial Cash).
      final txnId = referenceId != null
          ? 'txn-${now.microsecondsSinceEpoch}-$type-$referenceId'
          : 'txn-${now.microsecondsSinceEpoch}';

      await into(walletTransactions).insert(
        WalletTransactionsCompanion.insert(
          txnId: txnId,
          walletId: wallet.walletId,
          type: type,
          amountKobo: amountKobo.abs(),
          referenceType: note ?? referenceType,
          referenceId: Value(referenceId),
          performedBy: staffId,
          createdAt: Value(now),
          businessId: Value(wallet.businessId),
          lastUpdatedAt: Value(now),
        ),
      );

      // 3. Queue both the new wallet_transactions row and the updated
      // customers row (cached balance) for Supabase.
      final txn = await (select(walletTransactions)
            ..where((t) => t.txnId.equals(txnId)))
          .getSingle();
      await db.syncDao.enqueue(
        // txn_id (TEXT) is the cloud PK — no `id` column exists.
        'wallet_transactions:upsert:txn_id',
        jsonEncode({
          'txn_id': txn.txnId,
          'business_id': txn.businessId,
          'wallet_id': txn.walletId,
          'type': txn.type,
          'amount_kobo': txn.amountKobo,
          'reference_type': txn.referenceType,
          'reference_id': txn.referenceId,
          'performed_by': txn.performedBy,
          'customer_verified': txn.customerVerified,
          'created_at': txn.createdAt.toIso8601String(),
          'last_updated_at': txn.lastUpdatedAt?.toIso8601String(),
        }),
        businessId: txn.businessId ?? db.currentBusinessId!,
      );

      final updatedCustomer = await findById(customerId);
      if (updatedCustomer != null) {
        await db.syncDao.enqueue(
          'customers:update',
          jsonEncode(_customerPayload(updatedCustomer)),
          businessId: updatedCustomer.businessId ?? db.currentBusinessId!,
        );
      }
    });
  }

  /// Alias for updateWalletBalance to maintain compatibility with OrderService
  Future<void> recordWalletTransaction({
    required int customerId,
    required int amountKobo,
    required String type,
    required String referenceId,
    required int staffId,
    String note = 'order_payment',
  }) => updateWalletBalance(
    customerId: customerId,
    amountKobo: amountKobo,
    type: type,
    referenceType: note,
    referenceId: referenceId,
    staffId: staffId,
    note: note,
  );

  Stream<List<WalletTransactionData>> watchWalletHistory(int customerId) {
    final query =
        select(walletTransactions).join([
            leftOuterJoin(
              customerWallets,
              customerWallets.walletId.equalsExp(walletTransactions.walletId),
            ),
          ])
          ..where(customerWallets.customerId.equals(customerId))
          ..orderBy([OrderingTerm.desc(walletTransactions.createdAt)]);

    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(walletTransactions)).toList(),
    );
  }

  Future<CustomerWalletData?> getWalletInfo(int customerId) {
    return (select(
      customerWallets,
    )..where((t) => t.customerId.equals(customerId))).getSingleOrNull();
  }

  Future<void> updateWalletLimit(int customerId, int limitKobo) async {
    await transaction(() async {
      final now = DateTime.now();
      await (update(customers)..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          walletLimitKobo: Value(limitKobo),
          lastUpdatedAt: Value(now),
        ),
      );
      final updated = await findById(customerId);
      if (updated != null) {
        await db.syncDao.enqueue(
          'customers:update',
          jsonEncode(_customerPayload(updated)),
          businessId: updated.businessId ?? db.currentBusinessId!,
        );
      }
    });
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
    await transaction(() async {
      final now = DateTime.now();
      final customer = await findById(customerId);
      final businessId = customer?.businessId;
      final existing =
          await (select(customerCrateBalances)..where(
                (t) =>
                    t.customerId.equals(customerId) &
                    t.crateGroupId.equals(crateGroupId),
              ))
              .getSingleOrNull();

      if (existing != null) {
        final newBalance = existing.balance - deltaQty;
        await (update(customerCrateBalances)..where(
              (t) =>
                  t.customerId.equals(customerId) &
                  t.crateGroupId.equals(crateGroupId),
            ))
            .write(CustomerCrateBalancesCompanion(
              balance: Value(newBalance),
              lastUpdatedAt: Value(now),
            ));
      } else {
        await into(customerCrateBalances).insert(
          CustomerCrateBalancesCompanion(
            customerId: Value(customerId),
            crateGroupId: Value(crateGroupId),
            balance: Value(-deltaQty),
            businessId: Value(businessId),
            lastUpdatedAt: Value(now),
          ),
        );
      }

      await _enqueueCrateBalance(customerId, crateGroupId, businessId, now);
    });
  }

  /// Records returned crates for a customer/group pair.
  /// A negative balance means the customer has returned more than they owe (credit).
  /// Each call reduces the outstanding by [returnedQty].
  Future<void> recordCrateReturn(
    int customerId,
    int crateGroupId,
    int returnedQty,
  ) async {
    await transaction(() async {
      final now = DateTime.now();
      final customer = await findById(customerId);
      final businessId = customer?.businessId;
      final existing =
          await (select(customerCrateBalances)..where(
                (t) =>
                    t.customerId.equals(customerId) &
                    t.crateGroupId.equals(crateGroupId),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (update(customerCrateBalances)..where(
              (t) =>
                  t.customerId.equals(customerId) &
                  t.crateGroupId.equals(crateGroupId),
            ))
            .write(
              CustomerCrateBalancesCompanion(
                balance: Value(existing.balance - returnedQty),
                lastUpdatedAt: Value(now),
              ),
            );
      } else {
        await into(customerCrateBalances).insert(
          CustomerCrateBalancesCompanion(
            customerId: Value(customerId),
            crateGroupId: Value(crateGroupId),
            balance: Value(-returnedQty),
            businessId: Value(businessId),
            lastUpdatedAt: Value(now),
          ),
        );
      }

      await _enqueueCrateBalance(customerId, crateGroupId, businessId, now);
    });
  }

  /// Pushes a customer_crate_balances row to Supabase via the sync queue.
  /// Skips negative `crateGroupId`s — those are sentinels used by
  /// [recordCrateReturnByManufacturer] and don't satisfy the cloud FK to
  /// `crate_groups`. Composite-PK upsert needs an explicit conflict target.
  Future<void> _enqueueCrateBalance(
    int customerId,
    int crateGroupId,
    int? businessId,
    DateTime now,
  ) async {
    if (crateGroupId < 0) return;
    final row = await (select(customerCrateBalances)
          ..where((t) =>
              t.customerId.equals(customerId) &
              t.crateGroupId.equals(crateGroupId)))
        .getSingleOrNull();
    if (row == null) return;
    await db.syncDao.enqueue(
      'customer_crate_balances:upsert:customer_id,crate_group_id',
      jsonEncode({
        'business_id': row.businessId,
        'customer_id': row.customerId,
        'crate_group_id': row.crateGroupId,
        'balance': row.balance,
        'last_updated_at': row.lastUpdatedAt?.toIso8601String() ??
            now.toIso8601String(),
      }),
      businessId: row.businessId ?? businessId ?? db.currentBusinessId!,
    );
  }

  /// Records returned crates keyed by manufacturer (rather than crate group).
  /// Internally uses the existing CustomerCrateBalances table with a sentinel
  /// `crateGroupId = -manufacturerId` (negative ids never collide with real
  /// CrateGroup primary keys, which are positive auto-increments).
  /// A negative balance means the customer has returned more than they owe.
  Future<void> recordCrateReturnByManufacturer(
    int customerId,
    int manufacturerId,
    int returnedQty,
  ) async {
    final sentinel = -manufacturerId;
    // Sentinel IDs are negative and don't exist in CrateGroups, so we
    // temporarily disable FK enforcement for this upsert only.
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await recordCrateReturn(customerId, sentinel, returnedQty);
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Stream<Map<String, int>> watchCrateBalance(int customerId) =>
      Stream.value({});

  Future<int> getWalletBalance(String walletId) async {
    final credits = walletTransactions.amountKobo.sum(
      filter: walletTransactions.type.equals('credit'),
    );
    final debits = walletTransactions.amountKobo.sum(
      filter: walletTransactions.type.equals('debit'),
    );

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
class DeliveriesDao extends DatabaseAccessor<AppDatabase>
    with _$DeliveriesDaoMixin {
  DeliveriesDao(super.db);
  Stream<List<DeliveryData>> watchAll() => select(purchases).watch();
  Future<void> receiveDelivery(
    PurchasesCompanion delivery,
    List<PurchaseItemsCompanion> items,
  ) async {}
  Future<void> confirmDelivery(
    String deliveryIdStr,
    String confirmedBy,
  ) async {}

  /// Returns the most recent delivery (purchase) for a product, or null if none.
  Future<LastDeliveryInfo?> getLastDeliveryForProduct(int productId) async {
    final query =
        select(purchaseItems).join([
            innerJoin(
              purchases,
              purchases.id.equalsExp(purchaseItems.purchaseId),
            ),
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
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.db);
  Stream<List<ExpenseData>> watchAll({int? warehouseId}) {
    if (warehouseId == null) return select(expenses).watch();
    return (select(
      expenses,
    )..where((t) => t.warehouseId.equals(warehouseId))).watch();
  }

  Future<void> addExpense(ExpensesCompanion companion) async {
    await transaction(() async {
      final withSync = companion.copyWith(
        lastUpdatedAt: Value(DateTime.now()),
      );
      final id = await into(expenses).insert(withSync);

      // Queue for Sync
      await db.syncDao.enqueue(
        'expenses:insert',
        jsonEncode({
          'id': id,
          'business_id': companion.businessId.value,
          'category_id': companion.categoryId.value,
          'category': companion.category.value,
          'amount_kobo': companion.amountKobo.value,
          'description': companion.description.value,
          'payment_method': companion.paymentMethod.value,
          'recorded_by': companion.recordedBy.value,
          'reference': companion.reference.value,
          'timestamp': (companion.timestamp.present
                  ? companion.timestamp.value
                  : DateTime.now())
              .toIso8601String(),
          'warehouse_id': companion.warehouseId.value,
          'last_updated_at': DateTime.now().toIso8601String(),
          'is_deleted': false,
        }),
        businessId: companion.businessId.value ?? db.currentBusinessId!,
      );
    });
  }
  Stream<double> watchTotalThisMonth() => Stream.value(0.0);
}

@DriftAccessor(tables: [SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);
  /// Items eligible for an immediate push attempt: not yet synced, and either
  /// pending/in_progress, or previously failed but past their backoff window.
  /// `nextAttemptAt IS NULL` is treated as eligible so legacy `failed` rows
  /// (written before backoff was wired up) get one fresh chance.
  Future<List<SyncQueueData>> getPendingItems({int limit = 50, int? businessId}) {
    final now = DateTime.now();
    final query = select(syncQueue)
      ..where((t) =>
          t.isSynced.not() &
          (t.status.isIn(['pending', 'in_progress']) |
              (t.status.equals('failed') &
                  (t.nextAttemptAt.isNull() |
                      t.nextAttemptAt.isSmallerOrEqualValue(now)))));
    if (businessId != null) {
      query.where((t) => t.businessId.equals(businessId));
    }
    return (query..limit(limit)).get();
  }

  Future<void> markInProgress(int id) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        const SyncQueueCompanion(status: Value('in_progress')),
      );
  Future<void> markDone(int id) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        const SyncQueueCompanion(status: Value('done'), isSynced: Value(true)),
      );

  /// Records a failure with exponential backoff. Keeps `isSynced=false` so
  /// the row is preserved for diagnosis, but bumps `nextAttemptAt` so the
  /// auto-push loop stops hot-retrying a known-broken payload.
  Future<void> markFailed(int id, String error, {bool permanent = false}) async {
    final row = await (select(syncQueue)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final attempts = (row?.attempts ?? 0) + 1;
    final backoffMinutes = attempts > 6 ? 60 : (1 << (attempts - 1));
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('failed'),
        errorMessage: Value(error),
        attempts: Value(attempts),
        nextAttemptAt:
            Value(DateTime.now().add(Duration(minutes: backoffMinutes))),
      ),
    );
  }

  /// Same predicate as [getPendingItems] so the sidebar badge reflects
  /// "items eligible to push," not items wedged forever in `failed`.
  Stream<int> watchPendingCount() {
    return select(syncQueue).watch().map((rows) {
      final now = DateTime.now();
      return rows.where((e) {
        if (e.isSynced) return false;
        if (e.status == 'pending' || e.status == 'in_progress') return true;
        if (e.status == 'failed') {
          return e.nextAttemptAt == null || !e.nextAttemptAt!.isAfter(now);
        }
        return false;
      }).length;
    });
  }

  /// Recovers items abandoned by a crash mid-sync. Call once at service start.
  Future<void> resetStuckInProgress() =>
      (update(syncQueue)..where((t) => t.status.equals('in_progress'))).write(
        const SyncQueueCompanion(status: Value('pending')),
      );

  /// Wipes backoff state on `failed` rows so they're immediately eligible
  /// for re-push. Use after recovering from a global cause of failure
  /// (e.g. fresh sign-in that grants the missing JWT).
  Future<void> clearFailureBackoff() =>
      (update(syncQueue)..where((t) => t.status.equals('failed'))).write(
        const SyncQueueCompanion(
          status: Value('pending'),
          attempts: Value(0),
          nextAttemptAt: Value(null),
          errorMessage: Value(null),
        ),
      );

  /// Diagnostic: rows currently parked in `failed` state. Used by the
  /// kDebugMode startup log in SupabaseSyncService.
  Future<List<SyncQueueData>> getFailedItems({int limit = 50}) =>
      (select(syncQueue)
            ..where((t) => t.status.equals('failed'))
            ..limit(limit))
          .get();

  Stream<List<SyncQueueData>> watchFailedItems({int limit = 100}) =>
      (select(syncQueue)
            ..where((t) => t.status.equals('failed'))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(limit))
          .watch();

  Stream<int> watchFailedCount() =>
      (selectOnly(syncQueue)
            ..addColumns([syncQueue.id.count()])
            ..where(syncQueue.status.equals('failed')))
          .watchSingle()
          .map((row) => row.read(syncQueue.id.count()) ?? 0);

  /// Resets one failed row to `pending` so the next push tick retries it.
  Future<void> clearFailureBackoffById(int id) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        const SyncQueueCompanion(
          status: Value('pending'),
          attempts: Value(0),
          nextAttemptAt: Value(null),
          errorMessage: Value(null),
        ),
      );

  Future<void> discardQueueItem(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  Future<void> purgeOldDoneItems() =>
      (delete(syncQueue)..where((t) => t.isSynced)).go();

  Future<void> enqueue(
    String actionType,
    String payload, {
    required int businessId,
  }) =>
      into(syncQueue).insert(SyncQueueCompanion.insert(
        actionType: actionType,
        payload: payload,
        businessId: Value(businessId),
      ));
}

@DriftAccessor(tables: [ActivityLogs])
class ActivityLogDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityLogDaoMixin, BusinessScopedDao<AppDatabase> {
  ActivityLogDao(super.db);
  Future<void> log({
    int? staffId,
    required String action,
    required String description,
    String? entityId,
    String? entityType,
    String? warehouseId,
  }) => into(activityLogs).insert(
    ActivityLogsCompanion.insert(
      userId: Value(staffId),
      action: action,
      description: description,
      relatedEntityId: Value(entityId),
      relatedEntityType: Value(entityType),
      warehouseId: Value(warehouseId),
      businessId: Value(requireBusinessId()),
    ),
  );
  Stream<List<ActivityLogData>> watchRecent({int limit = 100}) =>
      (select(activityLogs)
            ..where((t) => t.businessId.equals(requireBusinessId()))
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
            ..limit(limit))
          .watch();
  Future<List<ActivityLogData>> getForEntity(String entityId) => (select(
    activityLogs,
  )..where((t) =>
      t.relatedEntityId.equals(entityId) &
      t.businessId.equals(requireBusinessId()))).get();
  Future<List<ActivityLogData>> getStockCountLogs() =>
      (select(activityLogs)
            ..where((t) =>
                t.action.equals('stock_count') &
                t.businessId.equals(requireBusinessId()))
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
          .get();
}

@DriftAccessor(tables: [Users, Warehouses])
class WarehousesDao extends DatabaseAccessor<AppDatabase>
    with _$WarehousesDaoMixin {
  WarehousesDao(super.db);
  Stream<WarehouseData?> watchWarehouse(int id) =>
      (select(warehouses)..where((t) => t.id.equals(id))).watchSingleOrNull();
  Future<WarehouseData?> getWarehouse(int id) =>
      (select(warehouses)..where((t) => t.id.equals(id))).getSingleOrNull();
  Stream<List<UserData>> watchAllStaff() => select(users).watch();
  Future<List<UserData>> getRiders() =>
      (select(users)..where((t) => t.role.equals('rider'))).get();
  Stream<List<UserData>> watchStaffByWarehouse(int warehouseId) =>
      (select(users)..where((t) => t.warehouseId.equals(warehouseId))).watch();
  Future<void> assignStaffToWarehouse(int userId, int? warehouseId) =>
      (update(users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(warehouseId: Value(warehouseId)),
      );
  Stream<Map<int, int>> watchWarehouseStaffCounts() => Stream.value({});
  Future<UserData?> getUserById(int id) =>
      (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<UserData?> getUserByEmail(String email) =>
      (select(users)..where((t) => t.email.equals(email))).getSingleOrNull();
}

@DriftAccessor(tables: [Notifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin {
  NotificationsDao(super.db);
  Future<void> create(String type, String message, {String? linkedRecordId}) =>
      into(notifications).insert(
        NotificationsCompanion.insert(
          type: type,
          message: message,
          linkedRecordId: Value(linkedRecordId),
        ),
      );
  Stream<List<NotificationData>> watchAll() => (select(
    notifications,
  )..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  Stream<int> watchUnreadCount() => select(
    notifications,
  ).watch().map((l) => l.where((e) => !e.isRead).length);
  Future<void> markRead(int id) =>
      (update(notifications)..where((t) => t.id.equals(id))).write(
        const NotificationsCompanion(isRead: Value(true)),
      );
  Future<void> markAllRead() => update(
    notifications,
  ).write(const NotificationsCompanion(isRead: Value(true)));
  Future<void> deleteSingle(int id) =>
      (delete(notifications)..where((t) => t.id.equals(id))).go();
  Future<void> clearAll() => delete(notifications).go();
}

@DriftAccessor(tables: [StockTransactions, Products, Users, Warehouses, Inventory])
class StockLedgerDao extends DatabaseAccessor<AppDatabase>
    with _$StockLedgerDaoMixin, BusinessScopedDao<AppDatabase> {
  StockLedgerDao(super.db);

  Future<int> getCurrentStock(int productId, int locationId) async {
    final delta = stockTransactions.quantityDelta.sum();
    return await (selectOnly(stockTransactions)
              ..where(stockTransactions.productId.equals(productId))
              ..where(stockTransactions.locationId.equals(locationId))
              ..addColumns([delta]))
            .map((row) => row.read(delta) ?? 0)
            .getSingleOrNull() ??
        0;
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

  Future<void> insertTransaction(StockTransactionsCompanion companion) =>
      into(stockTransactions).insert(companion);

  Stream<List<StockTransactionData>> watchLedger(int productId) {
    return (select(stockTransactions)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Streams all stock transactions with joined product/user/warehouse names.
  /// Filters by warehouse, date range, and movement type.
  Stream<List<StockTransactionWithDetails>> watchAllTransactionsFiltered({
    int? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
    String? movementType,
  }) {
    final u = alias(users, 'u');
    final w = alias(warehouses, 'w');

    final query = select(stockTransactions).join([
      innerJoin(products, products.id.equalsExp(stockTransactions.productId)),
      innerJoin(u, u.id.equalsExp(stockTransactions.performedBy)),
      innerJoin(w, w.id.equalsExp(stockTransactions.locationId)),
    ]);

    query.where(stockTransactions.businessId.equals(requireBusinessId()));

    if (warehouseId != null) {
      query.where(stockTransactions.locationId.equals(warehouseId));
    }
    if (startDate != null) {
      query.where(stockTransactions.createdAt
          .isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(stockTransactions.createdAt.isSmallerOrEqualValue(endDate));
    }
    if (movementType != null) {
      query.where(stockTransactions.movementType.equals(movementType));
    }

    query.orderBy([OrderingTerm.desc(stockTransactions.createdAt)]);

    return query.watch().map((rows) => rows.map((row) {
          final tx = row.readTable(stockTransactions);
          final product = row.readTable(products);
          final user = row.readTable(u);
          final warehouse = row.readTable(w);
          return StockTransactionWithDetails(
            transactionId: tx.transactionId,
            productId: product.id,
            productName: product.name,
            movementType: tx.movementType,
            quantityDelta: tx.quantityDelta,
            performedByName: user.name,
            locationId: tx.locationId,
            warehouseName: warehouse.name,
            referenceId: tx.referenceId,
            createdAt: tx.createdAt,
            unitPriceKobo: product.retailPriceKobo,
          );
        }).toList());
  }

  /// One-shot version of [watchAllTransactionsFiltered].
  Future<List<StockTransactionWithDetails>> getTransactionsFiltered({
    int? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
    String? movementType,
  }) {
    final u = alias(users, 'u');
    final w = alias(warehouses, 'w');

    final query = select(stockTransactions).join([
      innerJoin(products, products.id.equalsExp(stockTransactions.productId)),
      innerJoin(u, u.id.equalsExp(stockTransactions.performedBy)),
      innerJoin(w, w.id.equalsExp(stockTransactions.locationId)),
    ]);

    query.where(stockTransactions.businessId.equals(requireBusinessId()));

    if (warehouseId != null) {
      query.where(stockTransactions.locationId.equals(warehouseId));
    }
    if (startDate != null) {
      query.where(stockTransactions.createdAt
          .isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(stockTransactions.createdAt.isSmallerOrEqualValue(endDate));
    }
    if (movementType != null) {
      query.where(stockTransactions.movementType.equals(movementType));
    }

    query.orderBy([OrderingTerm.desc(stockTransactions.createdAt)]);

    return query.get().then((rows) => rows.map((row) {
          final tx = row.readTable(stockTransactions);
          final product = row.readTable(products);
          final user = row.readTable(u);
          final warehouse = row.readTable(w);
          return StockTransactionWithDetails(
            transactionId: tx.transactionId,
            productId: product.id,
            productName: product.name,
            movementType: tx.movementType,
            quantityDelta: tx.quantityDelta,
            performedByName: user.name,
            locationId: tx.locationId,
            warehouseName: warehouse.name,
            referenceId: tx.referenceId,
            createdAt: tx.createdAt,
            unitPriceKobo: product.retailPriceKobo,
          );
        }).toList());
  }

  /// Returns period summary: total inbound, total outbound, adjustment count.
  Future<PeriodStockSummary> getPeriodSummary({
    int? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final txs = await getTransactionsFiltered(
      warehouseId: warehouseId,
      startDate: startDate,
      endDate: endDate,
    );
    int totalIn = 0;
    int totalOut = 0;
    int adjustmentCount = 0;
    int flaggedCount = 0;
    for (final tx in txs) {
      if (tx.quantityDelta > 0) {
        totalIn += tx.quantityDelta;
      } else {
        totalOut += tx.quantityDelta.abs();
      }
      if (tx.movementType == 'adjustment') {
        adjustmentCount++;
        flaggedCount++;
      }
    }
    return PeriodStockSummary(
      totalIn: totalIn,
      totalOut: totalOut,
      adjustmentCount: adjustmentCount,
      flaggedCount: flaggedCount,
      transactionCount: txs.length,
    );
  }

  /// Returns all transactions for a product ordered by date ASC with running balance.
  Future<List<StockTransactionWithBalance>> getRunningBalanceForProduct(
    int productId, {
    int? warehouseId,
  }) async {
    final query = select(stockTransactions)
      ..where((t) => t.productId.equals(productId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    if (warehouseId != null) {
      query.where((t) => t.locationId.equals(warehouseId));
    }
    final txs = await query.get();
    int runningBalance = 0;
    final result = <StockTransactionWithBalance>[];
    for (final tx in txs) {
      final previous = runningBalance;
      runningBalance += tx.quantityDelta;
      result.add(StockTransactionWithBalance(
        transaction: tx,
        previousBalance: previous,
        newBalance: runningBalance,
        isFlagged: runningBalance < 0,
      ));
    }
    return result;
  }

  /// Computes the period reconciliation for all products in a warehouse.
  Future<PeriodReconciliation> getPeriodReconciliation({
    required int warehouseId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Opening stock: sum of all deltas before startDate for this warehouse
    final openingQuery = selectOnly(stockTransactions)
      ..addColumns([stockTransactions.quantityDelta.sum()])
      ..where(stockTransactions.locationId.equals(warehouseId) &
          stockTransactions.createdAt.isSmallerThanValue(startDate));
    final openingResult = await openingQuery
        .map((row) => row.read(stockTransactions.quantityDelta.sum()) ?? 0)
        .getSingleOrNull();
    final openingStock = openingResult ?? 0;

    // Period movements
    final periodTxs = await getTransactionsFiltered(
      warehouseId: warehouseId,
      startDate: startDate,
      endDate: endDate,
    );
    int stockIn = 0;
    int stockOut = 0;
    for (final tx in periodTxs) {
      if (tx.quantityDelta > 0) {
        stockIn += tx.quantityDelta;
      } else {
        stockOut += tx.quantityDelta.abs();
      }
    }

    final expectedClosing = openingStock + stockIn - stockOut;

    // Actual closing: sum of all inventory rows for this warehouse
    final actualQuery = selectOnly(inventory)
      ..addColumns([inventory.quantity.sum()])
      ..where(inventory.warehouseId.equals(warehouseId));
    final actualResult = await actualQuery
        .map((row) => row.read(inventory.quantity.sum()) ?? 0)
        .getSingleOrNull();
    final actualClosing = actualResult ?? 0;

    return PeriodReconciliation(
      openingStock: openingStock,
      stockIn: stockIn,
      stockOut: stockOut,
      expectedClosing: expectedClosing,
      actualClosing: actualClosing,
      variance: actualClosing - expectedClosing,
    );
  }

  Future<List<ProductBelowROP>> getProductsBelowROP(int locationId) async {
    final qty = stockTransactions.quantityDelta.sum();

    final query =
        (selectOnly(products)
            ..addColumns([
              products.id,
              products.name,
              products.avgDailySales,
              products.leadTimeDays,
              products.safetyStockQty,
              qty,
            ])
            ..join([
              leftOuterJoin(
                stockTransactions,
                stockTransactions.productId.equalsExp(products.id),
              ),
            ]))
          ..where(
            stockTransactions.locationId.equals(locationId) |
                stockTransactions.locationId.isNull(),
          )
          ..groupBy([products.id]);

    final results = await query.get();
    return results
        .map((row) {
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
        })
        .where((p) => p.currentStock <= p.rop)
        .toList();
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

class StockTransactionWithDetails {
  final String transactionId;
  final int productId;
  final String productName;
  final String movementType;
  final int quantityDelta;
  final String performedByName;
  final int locationId;
  final String? warehouseName;
  final String? referenceId;
  final DateTime createdAt;
  final int unitPriceKobo;

  StockTransactionWithDetails({
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantityDelta,
    required this.performedByName,
    required this.locationId,
    this.warehouseName,
    this.referenceId,
    required this.createdAt,
    required this.unitPriceKobo,
  });

  int get valueKobo => quantityDelta.abs() * unitPriceKobo;
  bool get isInflow => quantityDelta > 0;
  bool get isOutflow => quantityDelta < 0;
  bool get isAdjustment => movementType == 'adjustment';

  String get movementLabel {
    switch (movementType) {
      case 'sale':
        return 'Sale';
      case 'return':
        return 'Return';
      case 'damage':
        return 'Damaged';
      case 'transfer_out':
        return 'Transfer Out';
      case 'transfer_in':
        return 'Transfer In';
      case 'purchase_received':
        return 'Stock Received';
      case 'adjustment':
        return 'Adjustment';
      case 'transfer_cancelled':
        return 'Transfer Cancelled';
      default:
        return movementType;
    }
  }
}

class StockTransactionWithBalance {
  final StockTransactionData transaction;
  final int previousBalance;
  final int newBalance;
  final bool isFlagged;

  StockTransactionWithBalance({
    required this.transaction,
    required this.previousBalance,
    required this.newBalance,
    required this.isFlagged,
  });
}

class PeriodStockSummary {
  final int totalIn;
  final int totalOut;
  final int adjustmentCount;
  final int flaggedCount;
  final int transactionCount;

  PeriodStockSummary({
    required this.totalIn,
    required this.totalOut,
    required this.adjustmentCount,
    required this.flaggedCount,
    required this.transactionCount,
  });
}

class PeriodReconciliation {
  final int openingStock;
  final int stockIn;
  final int stockOut;
  final int expectedClosing;
  final int actualClosing;
  final int variance;

  PeriodReconciliation({
    required this.openingStock,
    required this.stockIn,
    required this.stockOut,
    required this.expectedClosing,
    required this.actualClosing,
    required this.variance,
  });

  bool get hasVariance => variance != 0;
}

@DriftAccessor(tables: [StockTransfers, StockTransactions])
class StockTransferDao extends DatabaseAccessor<AppDatabase>
    with _$StockTransferDaoMixin {
  StockTransferDao(super.db);

  String _generateUuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(10000)}';

  Future<void> initiateTransfer(StockTransfersCompanion companion) async {
    await transaction(() async {
      final id = await into(stockTransfers).insert(
        companion.copyWith(
          status: const Value('pending'),
          initiatedAt: Value(DateTime.now()),
        ),
      );
      await into(attachedDatabase.stockTransactions).insert(
        StockTransactionsCompanion.insert(
          transactionId: _generateUuid(),
          productId: companion.productId.value,
          locationId: companion.fromLocationId.value,
          quantityDelta: -companion.quantity.value,
          movementType: 'transfer_out',
          referenceId: Value(id.toString()),
          performedBy: companion.initiatedBy.value,
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> receiveTransfer(int transferId, int receivedBy) async {
    await transaction(() async {
      final transfer = await (select(
        stockTransfers,
      )..where((t) => t.transferId.equals(transferId))).getSingleOrNull();
      if (transfer == null ||
          (transfer.status != 'pending' && transfer.status != 'in_transit')) {
        throw Exception('Transfer cannot be received');
      }
      await (update(
        stockTransfers,
      )..where((t) => t.transferId.equals(transferId))).write(
        StockTransfersCompanion(
          status: const Value('received'),
          receivedBy: Value(receivedBy),
          receivedAt: Value(DateTime.now()),
        ),
      );
      await into(attachedDatabase.stockTransactions).insert(
        StockTransactionsCompanion.insert(
          transactionId: _generateUuid(),
          productId: transfer.productId,
          locationId: transfer.toLocationId,
          quantityDelta: transfer.quantity,
          movementType: 'transfer_in',
          referenceId: Value(transferId.toString()),
          performedBy: receivedBy,
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> cancelTransfer(int transferId) async {
    await transaction(() async {
      final transfer = await (select(
        stockTransfers,
      )..where((t) => t.transferId.equals(transferId))).getSingleOrNull();
      if (transfer == null) throw Exception('Transfer not found');
      if (transfer.status == 'received') {
        throw Exception('Cannot cancel received transfer');
      }
      await (update(stockTransfers)
            ..where((t) => t.transferId.equals(transferId)))
          .write(const StockTransfersCompanion(status: Value('cancelled')));
      final tx =
          await (select(attachedDatabase.stockTransactions)..where(
                (t) =>
                    t.referenceId.equals(transferId.toString()) &
                    t.movementType.equals('transfer_out'),
              ))
              .getSingleOrNull();
      if (tx != null) {
        await into(attachedDatabase.stockTransactions).insert(
          StockTransactionsCompanion.insert(
            transactionId: _generateUuid(),
            productId: transfer.productId,
            locationId: transfer.fromLocationId,
            quantityDelta: transfer.quantity,
            movementType: 'transfer_cancelled',
            referenceId: Value(transferId.toString()),
            performedBy: transfer.initiatedBy,
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}

@DriftAccessor(tables: [PendingCrateReturns])
class PendingCrateReturnsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingCrateReturnsDaoMixin {
  PendingCrateReturnsDao(super.db);

  Future<int> createPendingReturn({
    required int orderId,
    required int customerId,
    required int staffId,
    required String returnDataJson,
  }) => into(pendingCrateReturns).insert(
    PendingCrateReturnsCompanion.insert(
      orderId: orderId,
      customerId: customerId,
      staffId: staffId,
      returnDataJson: returnDataJson,
    ),
  );

  Future<PendingCrateReturnData?> getById(int id) => (select(
    pendingCrateReturns,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String newStatus) =>
      (update(pendingCrateReturns)..where((t) => t.id.equals(id))).write(
        PendingCrateReturnsCompanion(status: Value(newStatus)),
      );
}

extension CustomerDataExtension on CustomerData {
  String get addressText => address ?? 'N/A';
  double get customerWallet => walletBalanceKobo / 100.0;
}
