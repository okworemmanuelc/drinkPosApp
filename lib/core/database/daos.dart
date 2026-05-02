import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:reebaplus_pos/core/database/app_database.dart';
import 'package:reebaplus_pos/core/database/business_scoped_dao.dart';
import 'package:reebaplus_pos/core/database/uuid_v7.dart';

part 'daos.g.dart';

@DriftAccessor(
  tables: [Suppliers, Products, Categories, Warehouses, Manufacturers],
)
class CatalogDao extends DatabaseAccessor<AppDatabase>
    with _$CatalogDaoMixin, BusinessScopedDao<AppDatabase> {
  CatalogDao(super.db);

  Stream<List<SupplierData>> watchAllSupplierDatas() {
    return (select(suppliers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<SupplierData>> getAllSuppliers() {
    return (select(suppliers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<String> insertSupplier(SuppliersCompanion companion) async {
    final id = UuidV7.generate();
    await into(suppliers).insert(companion.copyWith(id: Value(id)));
    return id;
  }

  Future<String> insertProduct(ProductsCompanion companion) async {
    final id = UuidV7.generate();
    await into(products).insert(companion.copyWith(id: Value(id)));
    return id;
  }

  Future<List<ManufacturerData>> getAllManufacturers() {
    return (select(manufacturers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Stream<List<ProductData>> watchAvailableProductDatas({String? categoryId}) {
    final query = select(products)
      ..where(
        (t) =>
            whereBusiness(t) &
            t.isDeleted.not() &
            t.isAvailable.equals(true),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    return query.watch();
  }

  Future<ProductData?> findById(String id) {
    return (select(products)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .getSingleOrNull();
  }

  Future<ProductData?> findByName(String name) {
    return (select(products)
          ..where(
            (t) =>
                t.name.equals(name) &
                whereBusiness(t) &
                t.isDeleted.not(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> softDeleteProduct(String productId) async {
    await (update(products)
          ..where((t) => t.id.equals(productId) & whereBusiness(t)))
        .write(
      ProductsCompanion(
        isDeleted: const Value(true),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateProductDetails(
    String productId, {
    required String name,
    String? manufacturerId,
    required int buyingPriceKobo,
    required int retailPriceKobo,
    int? bulkBreakerPriceKobo,
    int? distributorPriceKobo,
    int? emptyCrateValueKobo,
    String? categoryId,
    String? unit,
    bool? trackEmpties,
    int? lowStockThreshold,
    String? imagePath,
  }) async {
    await (update(products)
          ..where((t) => t.id.equals(productId) & whereBusiness(t)))
        .write(
      ProductsCompanion(
        name: Value(name),
        manufacturerId: Value(manufacturerId),
        buyingPriceKobo: Value(buyingPriceKobo),
        retailPriceKobo: Value(retailPriceKobo),
        bulkBreakerPriceKobo: Value(bulkBreakerPriceKobo),
        distributorPriceKobo: Value(distributorPriceKobo),
        emptyCrateValueKobo: emptyCrateValueKobo == null
            ? const Value.absent()
            : Value(emptyCrateValueKobo),
        categoryId: Value(categoryId),
        unit: unit == null ? const Value.absent() : Value(unit),
        trackEmpties: trackEmpties == null
            ? const Value.absent()
            : Value(trackEmpties),
        lowStockThreshold: lowStockThreshold == null
            ? const Value.absent()
            : Value(lowStockThreshold),
        imagePath: Value(imagePath),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<String>> getUniqueProductUnits() async {
    final query = selectOnly(products, distinct: true)
      ..addColumns([products.unit])
      ..where(
        whereBusiness(products) & products.isDeleted.not(),
      );
    final rows = await query.get();
    return rows.map((r) => r.read(products.unit)!).toList();
  }

  Future<void> updateMonthlyTarget(String productId, int targetUnits) async {
    await (update(products)
          ..where((t) => t.id.equals(productId) & whereBusiness(t)))
        .write(
      ProductsCompanion(
        monthlyTargetUnits: Value(targetUnits),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  int getPriceForCustomerGroup(ProductData product, String group) {
    switch (group) {
      case 'wholesaler':
        return product.distributorPriceKobo ?? product.retailPriceKobo;
      default:
        return product.retailPriceKobo;
    }
  }

  Future<void> updateManufacturerEmptyCrateValue(
    String manufacturerId,
    int valueKobo,
  ) async {
    await (update(manufacturers)
          ..where((t) => t.id.equals(manufacturerId) & whereBusiness(t)))
        .write(
      ManufacturersCompanion(
        depositAmountKobo: Value(valueKobo),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateTrackEmpties(String productId, bool value) async {
    await (update(products)
          ..where((t) => t.id.equals(productId) & whereBusiness(t)))
        .write(
      ProductsCompanion(
        trackEmpties: Value(value),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }
}

@DriftAccessor(
  tables: [
    Products,
    Inventory,
    Warehouses,
    CrateGroups,
    Manufacturers,
    Categories,
    StockAdjustments,
    StockTransactions,
  ],
)
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin, BusinessScopedDao<AppDatabase> {
  InventoryDao(super.db);

  Stream<List<ManufacturerData>> watchAllManufacturers() {
    return (select(manufacturers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<ManufacturerData>> getAllManufacturers() {
    return (select(manufacturers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<String> insertManufacturer(ManufacturersCompanion companion) async {
    final id = UuidV7.generate();
    await into(manufacturers).insert(companion.copyWith(id: Value(id)));
    return id;
  }

  Future<void> updateManufacturerStock(String id, int newStock) async {
    await (update(manufacturers)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .write(
      ManufacturersCompanion(
        emptyCrateStock: Value(newStock),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateManufacturerDeposit(String id, int depositKobo) async {
    await (update(manufacturers)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .write(
      ManufacturersCompanion(
        depositAmountKobo: Value(depositKobo),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<ProductDataWithStock>> getProductsWithStock({
    String? warehouseId,
  }) async {
    final ps =
        await (select(products)
              ..where(
                (t) => whereBusiness(t) & t.isDeleted.not(),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.name)]))
            .get();
    final invQuery = select(inventory)
      ..where((t) => whereBusiness(t));
    if (warehouseId != null) {
      invQuery.where((t) => t.warehouseId.equals(warehouseId));
    }
    final invs = await invQuery.get();
    final totals = <String, int>{};
    for (final i in invs) {
      totals[i.productId] = (totals[i.productId] ?? 0) + i.quantity;
    }
    return ps
        .map(
          (p) =>
              ProductDataWithStock(product: p, totalStock: totals[p.id] ?? 0),
        )
        .toList();
  }

  Stream<List<ProductDataWithStock>> _watchProductsWithStock({
    String? categoryId,
    String? warehouseId,
    bool lowStockOnly = false,
  }) {
    final productsQuery = select(products)
      ..where((t) => whereBusiness(t) & t.isDeleted.not())
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (categoryId != null) {
      productsQuery.where((t) => t.categoryId.equals(categoryId));
    }
    final invQuery = select(inventory)
      ..where((t) => whereBusiness(t));
    if (warehouseId != null) {
      invQuery.where((t) => t.warehouseId.equals(warehouseId));
    }
    return Rx.combineLatest2<
      List<ProductData>,
      List<InventoryData>,
      List<ProductDataWithStock>
    >(productsQuery.watch(), invQuery.watch(), (ps, invs) {
      final totals = <String, int>{};
      for (final i in invs) {
        totals[i.productId] = (totals[i.productId] ?? 0) + i.quantity;
      }
      final out = ps
          .map(
            (p) =>
                ProductDataWithStock(product: p, totalStock: totals[p.id] ?? 0),
          )
          .toList();
      if (lowStockOnly) {
        return out
            .where((e) => e.totalStock <= e.product.lowStockThreshold)
            .toList();
      }
      return out;
    });
  }

  Stream<List<ProductDataWithStock>> watchProductsByCategory(
    String? categoryId,
  ) => _watchProductsWithStock(categoryId: categoryId);

  Stream<List<ProductDataWithStock>> watchProductsByWarehouse(
    String warehouseId,
  ) => _watchProductsWithStock(warehouseId: warehouseId);

  Stream<List<ProductDataWithStock>> watchAllProductDatasWithStock() =>
      _watchProductsWithStock();

  Stream<List<ProductDataWithStock>> watchLowStockProductDatas() =>
      _watchProductsWithStock(lowStockOnly: true);

  Stream<List<ProductDataWithStock>> watchProductDatasWithStockByWarehouse(
    String warehouseId,
  ) => _watchProductsWithStock(warehouseId: warehouseId);

  // No callers as of PR 4a; empty crates aren't tracked per-warehouse in the
  // current schema (manufacturer- and crate-group-scoped only). Returns 0 so
  // any future caller renders cleanly until PR 4c rewires crate aggregates.
  Stream<int> watchTotalEmptyCratesByWarehouse(String? warehouseId) =>
      Stream<int>.value(0);

  /// Adjust on-hand inventory by [delta] for ([productId], [warehouseId]).
  /// Append-only: writes a `stock_adjustments` row + a `stock_transactions`
  /// ledger row referencing it, then UPSERTs the inventory cache. Negative
  /// delta is guarded against quantity going negative.
  Future<void> adjustStock(
    String productId,
    String warehouseId,
    int delta,
    String note,
    String? staffId,
  ) async {
    if (delta == 0) return;
    await transaction(() async {
      // 1. Append stock_adjustments
      final adjustmentId = UuidV7.generate();
      await into(stockAdjustments).insert(
        StockAdjustmentsCompanion.insert(
          id: Value(adjustmentId),
          businessId: requireBusinessId(),
          productId: productId,
          warehouseId: warehouseId,
          quantityDiff: delta,
          reason: note,
          performedBy: Value(staffId),
        ),
      );

      // 2. Append stock_transactions ledger row
      await into(stockTransactions).insert(
        StockTransactionsCompanion.insert(
          businessId: requireBusinessId(),
          productId: productId,
          locationId: warehouseId,
          quantityDelta: delta,
          movementType: 'adjustment',
          adjustmentId: Value(adjustmentId),
          performedBy: Value(staffId),
        ),
      );

      // 3. UPSERT inventory cache
      if (delta >= 0) {
        await customStatement(
          'INSERT INTO inventory (id, business_id, product_id, warehouse_id, quantity) '
          'VALUES (?, ?, ?, ?, ?) '
          'ON CONFLICT(business_id, product_id, warehouse_id) DO UPDATE SET '
          'quantity = quantity + excluded.quantity, '
          'last_updated_at = CURRENT_TIMESTAMP',
          [UuidV7.generate(), requireBusinessId(), productId, warehouseId, delta],
        );
      } else {
        // Decrement with stock guard.
        final rowsAffected = await customUpdate(
          'UPDATE inventory SET quantity = quantity + ?, '
          'last_updated_at = CURRENT_TIMESTAMP '
          'WHERE business_id = ? AND product_id = ? AND warehouse_id = ? '
          'AND quantity >= ?',
          variables: [
            Variable(delta),
            Variable(requireBusinessId()),
            Variable(productId),
            Variable(warehouseId),
            Variable(-delta),
          ],
          updates: {inventory},
        );
        if (rowsAffected == 0) {
          throw InsufficientStockException(
            productId: productId,
            requested: -delta,
          );
        }
      }
    });
  }

  Stream<List<CategoryData>> watchAllCategories() {
    return (select(categories)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Stream<List<CrateGroupData>> watchAllCrateGroups() {
    return (select(crateGroups)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<CrateGroupData>> getAllCrateGroups() {
    return (select(crateGroups)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<void> updateCrateGroupStock(String groupId, int newStock) async {
    await (update(crateGroups)
          ..where((t) => t.id.equals(groupId) & whereBusiness(t)))
        .write(
      CrateGroupsCompanion(
        emptyCrateStock: Value(newStock),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Increment a manufacturer's empty-crate stock counter. Used by the
  /// receive-delivery and crate-return flows to credit the physical pool of
  /// returnable crates held against a manufacturer.
  Future<void> addEmptyCrates(String manufacturerId, int quantity) async {
    if (quantity == 0) return;
    await customUpdate(
      'UPDATE manufacturers SET empty_crate_stock = empty_crate_stock + ?, '
      'last_updated_at = CURRENT_TIMESTAMP '
      'WHERE id = ? AND business_id = ?',
      variables: [
        Variable(quantity),
        Variable(manufacturerId),
        Variable(requireBusinessId()),
      ],
      updates: {manufacturers},
    );
  }

  /// Stream the per-manufacturer count of full bottles in stock, derived
  /// from inventory rows joined with products on `manufacturer_id`.
  Stream<Map<String, int>> watchFullCratesByManufacturer() {
    final query = select(inventory).join([
      innerJoin(products, products.id.equalsExp(inventory.productId)),
    ])
      ..where(whereBusiness(inventory) &
          whereBusiness(products) &
          products.manufacturerId.isNotNull() &
          products.isDeleted.not());
    return query.watch().map((rows) {
      final out = <String, int>{};
      for (final row in rows) {
        final mfrId = row.readTable(products).manufacturerId;
        if (mfrId == null) continue;
        final qty = row.readTable(inventory).quantity;
        out[mfrId] = (out[mfrId] ?? 0) + qty;
      }
      return out;
    });
  }

  /// Stream per-manufacturer empty-crate stock from the manufacturers cache.
  Stream<Map<String, int>> watchEmptyCratesByManufacturer() {
    return (select(manufacturers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not()))
        .watch()
        .map((rows) => {for (final m in rows) m.id: m.emptyCrateStock});
  }

  /// Stream the total empty-crate assets across all manufacturers — used by
  /// the inventory dashboard summary card.
  Stream<int> watchTotalCrateAssets() {
    return (select(manufacturers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not()))
        .watch()
        .map((rows) => rows.fold<int>(0, (sum, m) => sum + m.emptyCrateStock));
  }

  Future<List<ProductStockWithWarehouse>> getProductsStockPerWarehouse({
    String? warehouseId,
  }) async {
    final ps = await (select(
      products,
    )..where((t) => whereBusiness(t) & t.isDeleted.not())).get();
    final whs = await (select(
      warehouses,
    )..where((t) => whereBusiness(t) & t.isDeleted.not())).get();
    final invQuery = select(inventory)
      ..where((t) => whereBusiness(t));
    if (warehouseId != null) {
      invQuery.where((t) => t.warehouseId.equals(warehouseId));
    }
    final invs = await invQuery.get();
    final productById = {for (final p in ps) p.id: p};
    final warehouseById = {for (final w in whs) w.id: w};
    final out = <ProductStockWithWarehouse>[];
    for (final i in invs) {
      final p = productById[i.productId];
      final w = warehouseById[i.warehouseId];
      if (p == null || w == null) continue;
      out.add(
        ProductStockWithWarehouse(
          warehouseId: w.id,
          warehouseName: w.name,
          product: p,
          totalStock: i.quantity,
        ),
      );
    }
    out.sort((a, b) => a.product.name.compareTo(b.product.name));
    return out;
  }
}

class ProductDataWithStock {
  final ProductData product;
  final int totalStock;
  ProductDataWithStock({required this.product, required this.totalStock});
}

class ProductStockWithWarehouse {
  final String warehouseId;
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
  final int totalBottles;
  final int emptyCrates;
  final int totalValueKobo;

  ManufacturerCrateStats({
    required this.manufacturer,
    required this.totalBottles,
    required this.emptyCrates,
    required this.totalValueKobo,
  });

  int get fullCratesEquiv => totalBottles;
  int get totalCrateAssets => totalBottles + emptyCrates;
}

@DriftAccessor(
  tables: [
    Orders,
    OrderItems,
    Products,
    Customers,
    SavedCarts,
    Categories,
    Inventory,
    StockTransactions,
    PaymentTransactions,
    WalletTransactions,
    CustomerWallets,
    Businesses,
  ],
)
class OrdersDao extends DatabaseAccessor<AppDatabase>
    with _$OrdersDaoMixin, BusinessScopedDao<AppDatabase> {
  OrdersDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  Future<OrderData?> findById(String id) {
    return (select(orders)
          ..where((o) => o.id.equals(id) & whereBusiness(o))
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<List<OrderData>> watchPendingOrders() {
    return (select(orders)
          ..where(
            (o) => whereBusiness(o) & o.status.equals('pending'),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Stream<List<OrderData>> watchAllOrders() {
    return (select(orders)
          ..where((o) => whereBusiness(o))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Stream<List<OrderData>> watchOrdersByWarehouse(String? warehouseId) {
    return (select(orders)
          ..where((o) {
            final expr = whereBusiness(o);
            if (warehouseId != null) {
              return expr & o.warehouseId.equals(warehouseId);
            }
            return expr;
          })
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Stream<List<OrderData>> watchCompletedOrders() {
    return (select(orders)
          ..where(
            (o) => whereBusiness(o) & o.status.equals('completed'),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Stream<List<OrderData>> watchCancelledOrders() {
    return (select(orders)
          ..where(
            (o) => whereBusiness(o) & o.status.equals('cancelled'),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Stream<List<OrderData>> watchOrdersByCustomer(String customerId) {
    return (select(orders)
          ..where(
            (o) => whereBusiness(o) & o.customerId.equals(customerId),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  // ── N+1 fix: single joined query + fold ────────────────────────────────────

  Stream<List<OrderWithItems>> watchAllOrdersWithItems({String? warehouseId}) {
    final query = select(orders).join([
      leftOuterJoin(orderItems, orderItems.orderId.equalsExp(orders.id)),
      leftOuterJoin(customers, customers.id.equalsExp(orders.customerId)),
      leftOuterJoin(products, products.id.equalsExp(orderItems.productId)),
    ]);
    query.where(whereBusiness(orders));
    if (warehouseId != null) {
      query.where(orders.warehouseId.equals(warehouseId));
    }
    query.orderBy([OrderingTerm.desc(orders.createdAt)]);

    return query.watch().map((rows) {
      // Fold flat join rows into structured OrderWithItems
      final Map<String, OrderWithItems> result = {};
      for (final row in rows) {
        final order = row.readTable(orders);
        final item = row.readTableOrNull(orderItems);
        final customer = row.readTableOrNull(customers);
        final product = row.readTableOrNull(products);

        result.putIfAbsent(order.id, () => OrderWithItems(order, [], customer));

        if (item != null && product != null) {
          result[order.id]!.items.add(
            OrderItemDataWithProductData(item, product),
          );
        }
      }
      return result.values.toList();
    });
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<void> assignRider(String orderId, String riderName) {
    return (update(
          orders,
        )..where((o) => o.id.equals(orderId) & whereBusiness(o)))
        .write(
          OrdersCompanion(
            riderName: Value(riderName),
            lastUpdatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Atomic order + items + inventory + ledger + payment + wallet in a single txn.
  /// Returns the new order ID.
  ///
  /// [walletDebitKobo] is the amount to debit from the customer's wallet. Used
  /// for wallet payments (full balance), partial payments (the remainder put on
  /// account), and credit sales (the full total). Requires [customerId].
  Future<String> createOrder({
    required OrdersCompanion order,
    required List<OrderItemsCompanion> items,
    String? customerId,
    required int amountPaidKobo,
    required int totalAmountKobo,
    required String staffId,
    String? warehouseId,
    int walletDebitKobo = 0,
    String paymentMethod = 'cash',
  }) {
    return db.transaction(() async {
      final orderId = order.id.present ? order.id.value : UuidV7.generate();

      // 1. Insert Order
      await into(orders).insert(order.copyWith(id: Value(orderId)));

      // 2. Insert OrderItems
      for (final item in items) {
        await into(orderItems).insert(item.copyWith(orderId: Value(orderId)));
      }

      // 3. Deduct Inventory — atomic guard (Issue #8)
      for (final item in items) {
        final qty = item.quantity.value;
        final productId = item.productId.value;
        final whId = item.warehouseId.value;

        final rowsAffected = await customUpdate(
          'UPDATE inventory SET quantity = quantity - ? '
          'WHERE business_id = ? AND product_id = ? '
          'AND warehouse_id = ? AND quantity >= ?',
          variables: [
            Variable(qty),
            Variable(requireBusinessId()),
            Variable(productId),
            Variable(whId),
            Variable(qty),
          ],
          updates: {inventory},
        );
        if (rowsAffected == 0) {
          throw InsufficientStockException(
            productId: productId,
            requested: qty,
          );
        }
      }

      // 4. Insert StockTransactions ledger rows
      for (final item in items) {
        await into(stockTransactions).insert(
          StockTransactionsCompanion.insert(
            businessId: requireBusinessId(),
            productId: item.productId.value,
            locationId: warehouseId ?? item.warehouseId.value,
            quantityDelta: -item.quantity.value,
            movementType: 'sale',
            orderId: Value(orderId),
            performedBy: Value(staffId),
          ),
        );
      }

      // 5. Insert PaymentTransactions only when cash actually changed hands.
      // Wallet/credit sales are recorded by the wallet ledger, not as a
      // 0-kobo payment row.
      if (amountPaidKobo > 0) {
        await into(paymentTransactions).insert(
          PaymentTransactionsCompanion.insert(
            businessId: requireBusinessId(),
            amountKobo: amountPaidKobo,
            method: paymentMethod,
            type: 'sale',
            orderId: Value(orderId),
            performedBy: Value(staffId),
          ),
        );
      }

      // 6. Insert WalletTransactions debit when the customer carries part or
      // all of the bill on their wallet (partial cash, full wallet, credit).
      if (walletDebitKobo > 0) {
        if (customerId == null) {
          throw ArgumentError(
            'walletDebitKobo > 0 requires a non-null customerId',
          );
        }
        final wallet =
            await (select(customerWallets)
                  ..where(
                    (w) =>
                        whereBusiness(w) &
                        w.customerId.equals(customerId) &
                        w.isDeleted.not(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (wallet == null) {
          throw StateError('Customer $customerId has no wallet — cannot debit');
        }
        await into(walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            businessId: requireBusinessId(),
            walletId: wallet.id,
            customerId: customerId,
            type: 'debit',
            amountKobo: walletDebitKobo,
            signedAmountKobo: -walletDebitKobo,
            referenceType: 'order_payment',
            orderId: Value(orderId),
            performedBy: Value(staffId),
          ),
        );
      }

      return orderId;
    });
  }

  Future<void> markCompleted(String orderId, [String? staffId]) {
    return db.transaction(() async {
      await (update(orders)..where(
            (o) => o.id.equals(orderId) & whereBusiness(o),
          ))
          .write(
            OrdersCompanion(
              status: const Value('completed'),
              staffId: staffId != null ? Value(staffId) : const Value.absent(),
              completedAt: Value(DateTime.now().toUtc()),
              lastUpdatedAt: Value(DateTime.now()),
            ),
          );
    });
  }

  /// Cancel an order: append compensating stock rows + void payments.
  Future<void> markCancelled(String orderId, String reason, String staffId) {
    return db.transaction(() async {
      // Update order status
      await (update(orders)..where(
            (o) => o.id.equals(orderId) & whereBusiness(o),
          ))
          .write(
            OrdersCompanion(
              status: const Value('cancelled'),
              cancellationReason: Value(reason),
              cancelledAt: Value(DateTime.now().toUtc()),
              lastUpdatedAt: Value(DateTime.now()),
            ),
          );

      // Stock: append COMPENSATING rows (ledger is append-only)
      final saleRows =
          await (select(stockTransactions)..where(
                (s) =>
                    s.orderId.equals(orderId) &
                    s.movementType.equals('sale') &
                    s.voidedAt.isNull(),
              ))
              .get();
      for (final row in saleRows) {
        await into(stockTransactions).insert(
          StockTransactionsCompanion.insert(
            businessId: requireBusinessId(),
            productId: row.productId,
            locationId: row.locationId,
            quantityDelta: -row.quantityDelta, // positive (return)
            movementType: 'return',
            orderId: Value(orderId),
            performedBy: Value(staffId),
          ),
        );
        // Restore inventory
        await customUpdate(
          'UPDATE inventory SET quantity = quantity + ? '
          'WHERE business_id = ? AND product_id = ? AND warehouse_id = ?',
          variables: [
            Variable(-row.quantityDelta),
            Variable(requireBusinessId()),
            Variable(row.productId),
            Variable(row.locationId),
          ],
          updates: {inventory},
        );
      }

      // Payment: void metadata ONLY (never append a new payment row)
      await (update(
        paymentTransactions,
      )..where((p) => p.orderId.equals(orderId) & p.voidedAt.isNull())).write(
        PaymentTransactionsCompanion(
          voidedAt: Value(DateTime.now().toUtc()),
          voidedBy: Value(staffId),
          voidReason: Value('order_cancelled: $reason'),
        ),
      );

      // Wallet: Refund any debit associated with the order (ledger is append-only)
      final originalDebit = await (select(walletTransactions)
            ..where(
              (t) =>
                  whereBusiness(t) &
                  t.orderId.equals(orderId) &
                  t.type.equals('debit'),
            )
            ..limit(1))
          .getSingleOrNull();

      if (originalDebit != null) {
        await into(walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            businessId: requireBusinessId(),
            walletId: originalDebit.walletId,
            customerId: originalDebit.customerId,
            type: 'credit',
            amountKobo: originalDebit.amountKobo,
            signedAmountKobo: originalDebit.amountKobo,
            referenceType: 'refund',
            orderId: Value(orderId),
            performedBy: Value(staffId),
          ),
        );
      }
    });
  }

  Future<String> generateOrderNumber() async {
    final count =
        await (selectOnly(orders)
              ..where(whereBusiness(orders))
              ..addColumns([orders.id.count()]))
            .map((row) => row.read(orders.id.count()) ?? 0)
            .getSingle();
    return 'ORD-${(count + 1).toString().padLeft(6, '0')}';
  }

  // ── Timezone-aware analytics ───────────────────────────────────────────────

  Future<ProductSalesSummary> getSalesSummaryForProduct(
    String productId,
  ) async {

    final business = await (select(
      businesses,
    )..where((b) => whereBusiness(b))).getSingleOrNull();
    final tzName = business?.timezone ?? 'UTC';

    tz.Location location;
    try {
      location = tz.getLocation(tzName);
    } on tz.LocationNotFoundException {
      debugPrint('[OrdersDao] Invalid timezone "$tzName", falling back to UTC');
      location = tz.UTC;
    }

    final now = tz.TZDateTime.now(location);
    final todayStart = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
    ).toUtc();
    final weekStart = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day - 6,
    ).toUtc();
    final monthStart = tz.TZDateTime(location, now.year, now.month, 1).toUtc();


    final query =
        select(orderItems).join([
          innerJoin(orders, orders.id.equalsExp(orderItems.orderId)),
        ])..where(
          orderItems.productId.equals(productId) &
              orders.status.equals('completed') &
              whereBusiness(orders),
        );

    final rows = await query.get();

    int todayUnits = 0, todayRevKobo = 0;
    int weekUnits = 0, weekRevKobo = 0;
    int monthUnits = 0, monthRevKobo = 0;

    for (final row in rows) {
      final item = row.readTable(orderItems);
      final order = row.readTable(orders);
      final date = order.createdAt.toUtc();

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

  // ── Cart staleness ─────────────────────────────────────────────────────────

  /// Compare each cart line's snapshot (productId, version, unitPriceKobo)
  /// against the live product row. Returns one [CartStaleItem] per drift —
  /// either the version was bumped (price/details changed since the line was
  /// added) or the resolved selling price differs.
  ///
  /// Single SELECT for the whole list (no N+1).
  Future<List<CartStaleItem>> checkCartStaleness(
    List<CartLineSnapshot> lines,
  ) async {
    if (lines.isEmpty) return const [];
    final ids = lines.map((l) => l.productId).toList();
    final rows = await (select(products)
          ..where((p) => p.id.isIn(ids) & p.isDeleted.not() & whereBusiness(p)))
        .get();
    final byId = {for (final p in rows) p.id: p};

    final stale = <CartStaleItem>[];
    for (final line in lines) {
      final p = byId[line.productId];
      if (p == null) continue; // product gone; UI handles separately
      final currentPriceKobo = p.sellingPriceKobo > 0
          ? p.sellingPriceKobo
          : p.retailPriceKobo;
      if (p.version != line.cartVersion ||
          currentPriceKobo != line.cartUnitPriceKobo) {
        stale.add(
          CartStaleItem(
            productId: p.id,
            productName: p.name,
            cartVersion: line.cartVersion,
            currentVersion: p.version,
            oldPriceKobo: line.cartUnitPriceKobo,
            newPriceKobo: currentPriceKobo,
          ),
        );
      }
    }
    return stale;
  }

  // ── Saved Carts ────────────────────────────────────────────────────────────

  Stream<List<SavedCartData>> watchSavedCarts() {
    return (select(savedCarts)
          ..where((c) => whereBusiness(c))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  Future<String> saveCart(SavedCartsCompanion companion) async {
    final id = companion.id.present ? companion.id.value : UuidV7.generate();
    await into(savedCarts).insert(companion.copyWith(id: Value(id)));
    return id;
  }

  Future<void> deleteSavedCart(String id) {
    return (delete(savedCarts)..where((c) => c.id.equals(id))).go();
  }

  Future<SavedCartData?> getSavedCart(String id) {
    return (select(savedCarts)
          ..where((c) => c.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }
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

class InsufficientStockException implements Exception {
  final String productId;
  final int requested;
  const InsufficientStockException({
    required this.productId,
    required this.requested,
  });
  @override
  String toString() =>
      'InsufficientStockException: product $productId, requested $requested';
}

class CartStaleItem {
  final String productId;
  final String productName;
  final int cartVersion;
  final int currentVersion;
  final int oldPriceKobo;
  final int newPriceKobo;
  const CartStaleItem({
    required this.productId,
    required this.productName,
    required this.cartVersion,
    required this.currentVersion,
    required this.oldPriceKobo,
    required this.newPriceKobo,
  });
}

class CartLineSnapshot {
  final String productId;
  final int cartVersion;
  final int cartUnitPriceKobo;
  const CartLineSnapshot({
    required this.productId,
    required this.cartVersion,
    required this.cartUnitPriceKobo,
  });
}

class CrateBalanceEntry {
  final String crateGroupId;
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
    CustomerCrateBalances,
    CustomerWallets,
    WalletTransactions,
    CrateGroups,
  ],
)
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin, BusinessScopedDao<AppDatabase> {
  CustomersDao(super.db);

  Stream<List<CustomerData>> watchAllCustomers() {
    return (select(customers)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Stream<List<CustomerData>> watchCustomersByWarehouse(String warehouseId) {
    return (select(customers)
          ..where(
            (t) => whereBusiness(t) &
                t.warehouseId.equals(warehouseId) &
                t.isDeleted.not(),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<CustomerData?> findById(String id) {
    return (select(customers)
          ..where(
            (t) =>
                t.id.equals(id) &
                whereBusiness(t) &
                t.isDeleted.not(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CustomerData?> findByPhone(String phone) {
    return (select(customers)
          ..where(
            (t) =>
                t.phone.equals(phone) &
                whereBusiness(t) &
                t.isDeleted.not(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<CustomerData?> watchCustomerById(String id) {
    return (select(customers)
          ..where(
            (t) =>
                t.id.equals(id) &
                whereBusiness(t) &
                t.isDeleted.not(),
          )
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<List<CrateBalanceEntry>> watchCrateBalancesWithGroups(
    String customerId,
  ) {
    final query =
        select(customerCrateBalances).join([
          innerJoin(
            crateGroups,
            crateGroups.id.equalsExp(customerCrateBalances.crateGroupId),
          ),
        ])..where(
          whereBusiness(customerCrateBalances) &
              customerCrateBalances.customerId.equals(customerId),
        );
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => CrateBalanceEntry(
              crateGroupId: r.readTable(customerCrateBalances).crateGroupId,
              groupName: r.readTable(crateGroups).name,
              balance: r.readTable(customerCrateBalances).balance,
            ),
          )
          .toList(),
    );
  }

  Future<String> addCustomer(CustomersCompanion customer) async {
    final customerId = UuidV7.generate();
    final walletId = UuidV7.generate();
    await transaction(() async {
      await into(customers).insert(
        customer.copyWith(id: Value(customerId), businessId: Value(requireBusinessId())),
      );
      await into(customerWallets).insert(
        CustomerWalletsCompanion.insert(
          id: Value(walletId),
          businessId: requireBusinessId(),
          customerId: customerId,
        ),
      );
    });
    return customerId;
  }

  // ── Wallet forwarders ────────────────────────────────────────────────────
  // Balance is derived from the WalletTransactions ledger; the legacy
  // `customers.wallet_balance_kobo` cache column is gone. These forwarders
  // keep the customer-screen API surface stable while routing through the
  // ledger DAO.

  Future<int> getWalletBalanceKobo(String customerId) {
    return attachedDatabase.walletTransactionsDao.getBalanceKobo(customerId);
  }

  Stream<int> watchWalletBalance(String customerId) {
    return attachedDatabase.walletTransactionsDao.watchBalanceKobo(customerId);
  }

  Stream<List<WalletTransactionData>> watchWalletHistory(String customerId) {
    return attachedDatabase.walletTransactionsDao.watchHistory(customerId);
  }

  Stream<Map<String, int>> watchAllWalletBalancesKobo() {
    return attachedDatabase.walletTransactionsDao.watchAllBalancesKobo();
  }

  Future<void> updateWalletLimit(String customerId, int limitKobo) {
    return attachedDatabase.customerWalletsDao
        .updateWalletLimit(customerId, limitKobo);
  }

  /// Append a wallet ledger entry. Used by legacy topup/refund flows in
  /// `CustomerService`. Pass an empty [staffId] when no auth context exists
  /// — it's stored as NULL.
  Future<void> updateWalletBalance({
    required String customerId,
    required int amountKobo,
    required String type,
    required String referenceType,
    String? note,
    String staffId = '',
  }) async {
    final wallet = await attachedDatabase.customerWalletsDao
        .getByCustomerId(customerId);
    if (wallet == null) {
      throw StateError('Customer $customerId has no wallet');
    }
    final signed = type == 'credit' ? amountKobo.abs() : -amountKobo.abs();
    await into(walletTransactions).insert(
      WalletTransactionsCompanion.insert(
        businessId: requireBusinessId(),
        walletId: wallet.id,
        customerId: customerId,
        type: type,
        amountKobo: amountKobo.abs(),
        signedAmountKobo: signed,
        referenceType: referenceType,
        performedBy: Value(staffId.isEmpty ? null : staffId),
      ),
    );
  }
}

@DriftAccessor(tables: [Purchases, PurchaseItems, Suppliers, Products])
class DeliveriesDao extends DatabaseAccessor<AppDatabase>
    with _$DeliveriesDaoMixin, BusinessScopedDao<AppDatabase> {
  DeliveriesDao(super.db);

  /// Most recent purchase row for a given product, exposed as a small struct
  /// for the product-detail screen. Returns null when the product has never
  /// been purchased.
  Future<LastDeliveryInfo?> getLastDeliveryForProduct(String productId) async {
    final query = select(purchaseItems).join([
      innerJoin(purchases, purchases.id.equalsExp(purchaseItems.purchaseId)),
    ])
      ..where(whereBusiness(purchaseItems) &
          purchaseItems.productId.equals(productId))
      ..orderBy([OrderingTerm.desc(purchases.createdAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final item = row.readTable(purchaseItems);
    final purchase = row.readTable(purchases);
    return LastDeliveryInfo(
      date: purchase.createdAt,
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

@DriftAccessor(tables: [Expenses, ExpenseCategories, ActivityLogs, PaymentTransactions])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin, BusinessScopedDao<AppDatabase> {
  ExpensesDao(super.db);

  Stream<List<ExpenseWithCategory>> watchAll({String? warehouseId}) {
    final query = select(expenses).join([
      leftOuterJoin(
        expenseCategories,
        expenseCategories.id.equalsExp(expenses.categoryId),
      ),
    ]);

    query.where(whereBusiness(expenses) & expenses.isDeleted.not());
    if (warehouseId != null) {
      query.where(expenses.warehouseId.equals(warehouseId));
    }
    query.orderBy([OrderingTerm.desc(expenses.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ExpenseWithCategory(
          expense: row.readTable(expenses),
          category: row.readTableOrNull(expenseCategories),
        );
      }).toList();
    });
  }

  Stream<List<ExpenseCategoryData>> watchAllCategories() {
    return (select(expenseCategories)
          ..where(
            (t) =>
                whereBusiness(t) & t.isDeleted.not(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<String> resolveCategoryId(String name) async {
    final normalized = name.trim();

    final existing = await (select(expenseCategories)
          ..where((t) => whereBusiness(t) & t.name.equals(normalized))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) return existing.id;

    final id = UuidV7.generate();
    await into(expenseCategories).insert(
      ExpenseCategoriesCompanion.insert(
        id: Value(id),
        businessId: requireBusinessId(),
        name: normalized,
      ),
    );
    return id;
  }

  Future<void> addExpense({
    required String categoryName,
    required int amountKobo,
    required String description,
    String? paymentMethod,
    String? reference,
    String? warehouseId,
    required String recordedBy,
  }) async {

    await transaction(() async {
      final categoryId = await resolveCategoryId(categoryName);
      final expenseId = UuidV7.generate();

      // 1. Insert Expense
      await into(expenses).insert(
        ExpensesCompanion.insert(
          id: Value(expenseId),
          businessId: requireBusinessId(),
          categoryId: Value(categoryId),
          amountKobo: amountKobo,
          description: description,
          paymentMethod: Value(paymentMethod),
          recordedBy: Value(recordedBy),
          reference: Value(reference),
          warehouseId: Value(warehouseId),
        ),
      );

      // 2. Append Activity Log
      await db.activityLogDao.log(
        action: 'expense_created',
        description: 'Recorded expense: $description ($categoryName)',
        staffId: recordedBy,
        expenseId: expenseId,
        warehouseId: warehouseId,
      );

      // 3. Append Payment Transaction
      await into(db.paymentTransactions).insert(
        PaymentTransactionsCompanion.insert(
          id: Value(UuidV7.generate()),
          businessId: requireBusinessId(),
          amountKobo: amountKobo,
          method: paymentMethod ?? 'other',
          type: 'expense',
          expenseId: Value(expenseId),
          performedBy: Value(recordedBy),
        ),
      );
    });
  }

  Stream<int> watchTotalThisMonth() {

    return db.settingsDao.watchTimezone().switchMap((timezoneName) {
      final location = tz.getLocation(timezoneName);
      final now = tz.TZDateTime.now(location);
      final startOfMonth = tz.TZDateTime(location, now.year, now.month, 1);
      final nextMonth = tz.TZDateTime(location, now.year, now.month + 1, 1);


      final query = selectOnly(expenses)
        ..addColumns([expenses.amountKobo.sum()])
        ..where(
          whereBusiness(expenses) &
              expenses.isDeleted.not() &
              expenses.createdAt.isBiggerOrEqualValue(startOfMonth) &
              expenses.createdAt.isSmallerThanValue(nextMonth),
        );

      return query.watchSingleOrNull().map((row) => row?.read(expenses.amountKobo.sum()) ?? 0);
    });
  }
}

class ExpenseWithCategory {
  final ExpenseData expense;
  final ExpenseCategoryData? category;
  ExpenseWithCategory({required this.expense, this.category});
}

@DriftAccessor(tables: [SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase>
    with _$SyncDaoMixin, BusinessScopedDao<AppDatabase> {
  SyncDao(super.db);

  Future<List<SyncQueueData>> getPendingItems({
    int limit = 50,
  }) {
    final query = select(syncQueue)
      ..where((t) =>
          t.isSynced.not() & t.status.equals('pending') & whereBusiness(t))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
      ])
      ..limit(limit);

    return query.get();
  }

  Future<void> markInProgress(String id) async {
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(status: Value('syncing')),
    );
  }

  Future<void> markDone(String id) async {
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(
        isSynced: Value(true),
        status: Value('completed'),
        nextAttemptAt: Value(null),
      ),
    );
  }

  Future<void> markFailed(String id, String error, {bool permanent = false}) async {
    final now = DateTime.now();
    // Simple exponential backoff: 2^attempts * 30 seconds
    final existing = await (select(syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();
    final attempts = (existing?.attempts ?? 0) + 1;
    final delay = Duration(seconds: (1 << (attempts % 10)) * 30);

    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        status: Value(permanent ? 'failed' : 'pending'),
        errorMessage: Value(error),
        attempts: Value(attempts),
        nextAttemptAt: Value(permanent ? null : now.add(delay)),
      ),
    );
  }

  Stream<int> watchPendingCount() {
    return (selectOnly(syncQueue)
          ..addColumns([syncQueue.id.count()])
          ..where(syncQueue.isSynced.not() & whereBusiness(syncQueue)))
        .watchSingle()
        .map((row) => row.read(syncQueue.id.count()) ?? 0);
  }

  Future<void> resetStuckInProgress() async {
    // Items stuck in 'syncing' for more than 5 minutes are reset to 'pending'
    final fiveMinsAgo = DateTime.now().subtract(const Duration(minutes: 5));
    await (update(syncQueue)
          ..where((t) =>
              t.status.equals('syncing') &
              t.createdAt.isSmallerThanValue(fiveMinsAgo) &
              whereBusiness(t)))
        .write(const SyncQueueCompanion(status: Value('pending')));
  }

  Future<void> clearFailureBackoff() async {
    await (update(syncQueue)
            ..where((t) => t.status.equals('pending') & whereBusiness(t)))
        .write(
      const SyncQueueCompanion(nextAttemptAt: Value(null)),
    );
  }

  Future<List<SyncQueueData>> getFailedItems({int limit = 50}) {
    return (select(syncQueue)
          ..where((t) => t.status.equals('failed') & whereBusiness(t))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<SyncQueueData>> watchFailedItems({int limit = 100}) {
    return (select(syncQueue)
          ..where((t) => t.status.equals('failed') & whereBusiness(t))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Stream<int> watchFailedCount() {
    return (selectOnly(syncQueue)
          ..addColumns([syncQueue.id.count()])
          ..where(syncQueue.status.equals('failed') & whereBusiness(syncQueue)))
        .watchSingle()
        .map((row) => row.read(syncQueue.id.count()) ?? 0);
  }

  Future<void> clearFailureBackoffById(String id) async {
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(nextAttemptAt: Value(null), status: Value('pending')),
    );
  }

  Future<void> discardQueueItem(String id) async {
    await (delete(syncQueue)..where((t) => t.id.equals(id))).go();
  }

  Future<void> purgeOldDoneItems() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    await (delete(syncQueue)
          ..where((t) => t.isSynced.equals(true) & t.createdAt.isSmallerThanValue(sevenDaysAgo)))
        .go();
  }

  Future<void> enqueue(
    String actionType,
    String payload,
  ) async {
    await into(syncQueue).insert(
      SyncQueueCompanion.insert(
        id: Value(UuidV7.generate()),
        businessId: requireBusinessId(),
        actionType: actionType,
        payload: payload,
      ),
    );
  }
}

@DriftAccessor(tables: [ActivityLogs])
class ActivityLogDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityLogDaoMixin, BusinessScopedDao<AppDatabase> {
  ActivityLogDao(super.db);

  Future<void> log({
    required String action,
    required String description,
    String? staffId,
    String? warehouseId,
    String? orderId,
    String? productId,
    String? customerId,
    String? expenseId,
    String? deliveryId,
    String? walletTxnId,
  }) async {
    await into(activityLogs).insert(
      ActivityLogsCompanion.insert(
        id: Value(UuidV7.generate()),
        businessId: requireBusinessId(),
        userId: Value(staffId),
        action: action,
        description: description,
        orderId: Value(orderId),
        productId: Value(productId),
        customerId: Value(customerId),
        expenseId: Value(expenseId),
        deliveryId: Value(deliveryId),
        walletTxnId: Value(walletTxnId),
        warehouseId: Value(warehouseId),
      ),
    );
  }

  Stream<List<ActivityLogData>> watchRecent({int limit = 100}) {
    return (select(activityLogs)
          ..where((t) => whereBusiness(t) & t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<ActivityLogData>> getForOrder(String orderId) {
    return (select(activityLogs)
          ..where((t) =>
              whereBusiness(t) &
              t.orderId.equals(orderId) &
              t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getForProduct(String productId) {
    return (select(activityLogs)
          ..where((t) =>
              whereBusiness(t) &
              t.productId.equals(productId) &
              t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getForCustomer(String customerId) {
    return (select(activityLogs)
          ..where((t) =>
              whereBusiness(t) &
              t.customerId.equals(customerId) &
              t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getForExpense(String expenseId) {
    return (select(activityLogs)
          ..where((t) =>
              whereBusiness(t) &
              t.expenseId.equals(expenseId) &
              t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getForDelivery(String deliveryId) {
    return (select(activityLogs)
          ..where((t) =>
              whereBusiness(t) &
              t.deliveryId.equals(deliveryId) &
              t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getForWalletTxn(String walletTxnId) {
    return (select(activityLogs)
          ..where((t) =>
              whereBusiness(t) &
              t.walletTxnId.equals(walletTxnId) &
              t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<List<ActivityLogData>> getStockCountLogs() {
    return (select(activityLogs)
          ..where((t) =>
              whereBusiness(t) &
              t.action.equals('stock_count') &
              t.voidedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }
}

@DriftAccessor(tables: [Users, Warehouses])
class WarehousesDao extends DatabaseAccessor<AppDatabase>
    with _$WarehousesDaoMixin, BusinessScopedDao<AppDatabase> {
  WarehousesDao(super.db);

  Stream<WarehouseData?> watchWarehouse(String id) {
    return (select(warehouses)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .watchSingleOrNull();
  }

  Future<WarehouseData?> getWarehouse(String id) {
    return (select(warehouses)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .getSingleOrNull();
  }

  Stream<List<UserData>> watchAllStaff() {
    return (select(users)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<UserData>> getRiders() {
    return (select(users)
          ..where(
            (t) =>
                whereBusiness(t) &
                t.isDeleted.not() &
                t.role.equals('rider'),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Stream<List<UserData>> watchStaffByWarehouse(String warehouseId) {
    return (select(users)
          ..where(
            (t) =>
                whereBusiness(t) &
                t.isDeleted.not() &
                t.warehouseId.equals(warehouseId),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<void> assignStaffToWarehouse(
    String userId,
    String? warehouseId,
  ) async {
    await (update(users)
          ..where((t) => t.id.equals(userId) & whereBusiness(t)))
        .write(
      UsersCompanion(
        warehouseId: Value(warehouseId),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<Map<String, int>> watchWarehouseStaffCounts() {
    return (select(users)..where(
          (t) =>
              whereBusiness(t) &
              t.isDeleted.not() &
              t.warehouseId.isNotNull(),
        ))
        .watch()
        .map((rows) {
          final counts = <String, int>{};
          for (final u in rows) {
            final wid = u.warehouseId;
            if (wid == null) continue;
            counts[wid] = (counts[wid] ?? 0) + 1;
          }
          return counts;
        });
  }

  Future<UserData?> getUserById(String id) {
    // deliberately not businessId-scoped
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<UserData?> getUserByEmail(String email) {
    // deliberately not businessId-scoped
    return (select(users)..where((t) => t.email.equals(email)))
        .getSingleOrNull();
  }
}

@DriftAccessor(tables: [Notifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin, BusinessScopedDao<AppDatabase> {
  NotificationsDao(super.db);

  Future<void> create(String type, String message, {String? linkedRecordId}) async {
    await into(notifications).insert(
      NotificationsCompanion.insert(
        id: Value(UuidV7.generate()),
        businessId: requireBusinessId(),
        type: type,
        message: message,
        linkedRecordId: Value(linkedRecordId),
      ),
    );
  }

  Stream<List<NotificationData>> watchAll() {
    return (select(notifications)
          ..where((t) => whereBusiness(t))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Stream<int> watchUnreadCount() {
    final count = notifications.id.count();
    return (selectOnly(notifications)
          ..addColumns([count])
          ..where(whereBusiness(notifications) &
              notifications.isRead.equals(false)))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Future<void> markRead(String id) async {
    await (update(notifications)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .write(
      const NotificationsCompanion(isRead: Value(true)),
    );
  }

  Future<void> markAllRead() async {
    await (update(notifications)..where((t) => whereBusiness(t)))
        .write(
      const NotificationsCompanion(isRead: Value(true)),
    );
  }

  Future<void> deleteSingle(String id) async {
    await (delete(notifications)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .go();
  }

  Future<void> clearAll() async {
    await (delete(notifications)..where((t) => whereBusiness(t)))
        .go();
  }
}

@DriftAccessor(
  tables: [StockTransactions, Products, Users, Warehouses, Inventory],
)
class StockLedgerDao extends DatabaseAccessor<AppDatabase>
    with _$StockLedgerDaoMixin, BusinessScopedDao<AppDatabase> {
  StockLedgerDao(super.db);

  Future<int> getCurrentStock(String productId, String locationId) async {
    final row =
        await (select(inventory)
              ..where(
                (i) =>
                    whereBusiness(i) &
                    i.productId.equals(productId) &
                    i.warehouseId.equals(locationId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.quantity ?? 0;
  }

  Stream<int> watchCurrentStock(String productId, String locationId) {
    return (select(inventory)
          ..where(
            (i) =>
                whereBusiness(i) &
                i.productId.equals(productId) &
                i.warehouseId.equals(locationId),
          )
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row?.quantity ?? 0);
  }

  Future<void> insertTransaction(StockTransactionsCompanion companion) {
    return into(stockTransactions).insert(companion);
  }

  Stream<List<StockTransactionData>> watchLedger(String productId) {
    return (select(stockTransactions)
          ..where(
            (s) =>
                whereBusiness(s) &
                s.productId.equals(productId) &
                s.voidedAt.isNull(),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .watch();
  }

  // ── Filtered queries with joined product/user/warehouse names ──────────

  JoinedSelectStatement<HasResultSet, dynamic> _buildFilteredQuery({
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
    String? movementType,
  }) {
    final query = select(stockTransactions).join([
      innerJoin(products, products.id.equalsExp(stockTransactions.productId)),
      innerJoin(users, users.id.equalsExp(stockTransactions.performedBy)),
      leftOuterJoin(
        warehouses,
        warehouses.id.equalsExp(stockTransactions.locationId),
      ),
    ]);
    query.where(
      whereBusiness(stockTransactions) &
          stockTransactions.voidedAt.isNull(),
    );
    if (warehouseId != null) {
      query.where(stockTransactions.locationId.equals(warehouseId));
    }
    if (startDate != null) {
      query.where(stockTransactions.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(stockTransactions.createdAt.isSmallerOrEqualValue(endDate));
    }
    if (movementType != null) {
      query.where(stockTransactions.movementType.equals(movementType));
    }
    query.orderBy([OrderingTerm.desc(stockTransactions.createdAt)]);
    return query;
  }

  StockTransactionWithDetails _mapRow(TypedResult row) {
    final s = row.readTable(stockTransactions);
    final p = row.readTable(products);
    final u = row.readTable(users);
    final w = row.readTableOrNull(warehouses);
    return StockTransactionWithDetails(
      transactionId: s.id,
      productId: s.productId,
      productName: p.name,
      movementType: s.movementType,
      quantityDelta: s.quantityDelta,
      performedByName: u.name,
      locationId: s.locationId,
      warehouseName: w?.name,
      referenceId: s.orderId ?? s.transferId ?? s.adjustmentId ?? s.purchaseId,
      createdAt: s.createdAt,
      unitPriceKobo: p.sellingPriceKobo > 0
          ? p.sellingPriceKobo
          : p.retailPriceKobo,
    );
  }

  Stream<List<StockTransactionWithDetails>> watchAllTransactionsFiltered({
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
    String? movementType,
  }) {
    return _buildFilteredQuery(
      warehouseId: warehouseId,
      startDate: startDate,
      endDate: endDate,
      movementType: movementType,
    ).watch().map((rows) => rows.map(_mapRow).toList());
  }

  Future<List<StockTransactionWithDetails>> getTransactionsFiltered({
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
    String? movementType,
  }) async {
    final rows = await _buildFilteredQuery(
      warehouseId: warehouseId,
      startDate: startDate,
      endDate: endDate,
      movementType: movementType,
    ).get();
    return rows.map(_mapRow).toList();
  }

  Future<PeriodStockSummary> getPeriodSummary({
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final txns = await getTransactionsFiltered(
      warehouseId: warehouseId,
      startDate: startDate,
      endDate: endDate,
    );
    int totalIn = 0, totalOut = 0, adjustments = 0, flagged = 0;
    for (final t in txns) {
      if (t.quantityDelta > 0) {
        totalIn += t.quantityDelta;
      } else {
        totalOut += t.quantityDelta.abs();
      }
      if (t.isAdjustment) adjustments++;
    }
    return PeriodStockSummary(
      totalIn: totalIn,
      totalOut: totalOut,
      adjustmentCount: adjustments,
      flaggedCount: flagged,
      transactionCount: txns.length,
    );
  }

  Future<List<StockTransactionWithBalance>> getRunningBalanceForProduct(
    String productId, {
    String? warehouseId,
  }) async {
    final query = select(stockTransactions)
      ..where(
        (s) =>
            whereBusiness(s) &
            s.productId.equals(productId) &
            s.voidedAt.isNull(),
      )
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    if (warehouseId != null) {
      query.where((s) => s.locationId.equals(warehouseId));
    }
    final txns = await query.get();
    int balance = 0;
    final result = <StockTransactionWithBalance>[];
    for (final txn in txns) {
      final prev = balance;
      balance += txn.quantityDelta;
      result.add(
        StockTransactionWithBalance(
          transaction: txn,
          previousBalance: prev,
          newBalance: balance,
          isFlagged: balance < 0,
        ),
      );
    }
    return result;
  }

  Future<PeriodReconciliation> getPeriodReconciliation({
    required String warehouseId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Get all transactions for this warehouse, sorted by time
    final allTxns =
        await (select(stockTransactions)
              ..where(
                (s) =>
                    whereBusiness(s) &
                    s.locationId.equals(warehouseId) &
                    s.voidedAt.isNull(),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
            .get();

    int openingStock = 0;
    int stockIn = 0;
    int stockOut = 0;

    for (final txn in allTxns) {
      if (txn.createdAt.isBefore(startDate)) {
        openingStock += txn.quantityDelta;
      } else if (!txn.createdAt.isAfter(endDate)) {
        if (txn.quantityDelta > 0) {
          stockIn += txn.quantityDelta;
        } else {
          stockOut += txn.quantityDelta.abs();
        }
      }
    }

    final expectedClosing = openingStock + stockIn - stockOut;

    // Get current actual stock from inventory table
    final invRows =
        await (select(inventory)..where(
              (i) =>
                  whereBusiness(i) &
                  i.warehouseId.equals(warehouseId),
            ))
            .get();
    final actualClosing = invRows.fold<int>(0, (s, r) => s + r.quantity);

    return PeriodReconciliation(
      openingStock: openingStock,
      stockIn: stockIn,
      stockOut: stockOut,
      expectedClosing: expectedClosing,
      actualClosing: actualClosing,
      variance: actualClosing - expectedClosing,
    );
  }

  Future<List<ProductBelowROP>> getProductsBelowROP(String locationId) async {
    final ps = await (select(
      products,
    )..where((p) => whereBusiness(p) & p.isDeleted.not())).get();
    final invs =
        await (select(inventory)..where(
              (i) =>
                  whereBusiness(i) &
                  i.warehouseId.equals(locationId),
            ))
            .get();
    final stockMap = <String, int>{};
    for (final i in invs) {
      stockMap[i.productId] = (stockMap[i.productId] ?? 0) + i.quantity;
    }
    final result = <ProductBelowROP>[];
    for (final p in ps) {
      final stock = stockMap[p.id] ?? 0;
      // ROP = avgDailySales * leadTimeDays + safetyStockQty
      final rop = p.avgDailySales * p.leadTimeDays + p.safetyStockQty;
      if (stock < rop) {
        result.add(
          ProductBelowROP(
            productId: p.id,
            productName: p.name,
            currentStock: stock,
            rop: rop,
          ),
        );
      }
    }
    return result;
  }
}

class ProductBelowROP {
  final String productId;
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
  final String productId;
  final String productName;
  final String movementType;
  final int quantityDelta;
  final String performedByName;
  final String locationId;
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
    with _$StockTransferDaoMixin, BusinessScopedDao<AppDatabase> {
  StockTransferDao(super.db);
  // Transfer flows have no UI callers today; methods will land alongside the
  // transfer screens. Keeping the shell preserves the AppDatabase accessor
  // registration so adding methods later doesn't require schema regen.
}

@DriftAccessor(tables: [PendingCrateReturns])
class PendingCrateReturnsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingCrateReturnsDaoMixin, BusinessScopedDao<AppDatabase> {
  PendingCrateReturnsDao(super.db);

  Future<String> createPendingReturn({
    required String? orderId,
    required String customerId,
    required String submittedBy,
    required String crateGroupId,
    required int quantity,
  }) async {
    final id = UuidV7.generate();
    await into(pendingCrateReturns).insert(
      PendingCrateReturnsCompanion.insert(
        id: Value(id),
        businessId: requireBusinessId(),
        orderId: Value(orderId),
        customerId: customerId,
        crateGroupId: crateGroupId,
        quantity: quantity,
        submittedBy: submittedBy,
      ),
    );
    return id;
  }

  Future<PendingCrateReturnData?> getById(String id) {
    return (select(pendingCrateReturns)
          ..where((t) => t.id.equals(id) & whereBusiness(t))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> updateStatus(String id, String newStatus) async {
    await (update(pendingCrateReturns)
          ..where((t) => t.id.equals(id) & whereBusiness(t)))
        .write(
      PendingCrateReturnsCompanion(
        status: Value(newStatus),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }
}

extension CustomerDataExtension on CustomerData {
  String get addressText => address ?? 'N/A';
}

@DriftAccessor(tables: [Sessions])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin, BusinessScopedDao<AppDatabase> {
  SessionsDao(super.db);

  Future<String> createSession({
    required String userId,
    required Duration ttl,
    String? userAgent,
    String? ipAddress,
    String? deviceId,
  }) async {
    final businessId = requireBusinessId();
    final id = UuidV7.generate();
    await into(sessions).insert(
      SessionsCompanion.insert(
        id: Value(id),
        businessId: businessId,
        userId: userId,
        expiresAt: DateTime.now().add(ttl),
        userAgent: Value(userAgent),
        ipAddress: Value(ipAddress),
        deviceId: Value(deviceId),
      ),
    );
    return id;
  }

  Future<void> revokeSession(String sessionId) async {
    await (update(sessions)
          ..where((t) => t.id.equals(sessionId) & whereBusiness(t)))
        .write(
      SessionsCompanion(
        revokedAt: Value(DateTime.now()),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> revokeAllSessionsForUser(String userId) async {
    final now = DateTime.now();
    await (update(sessions)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                whereBusiness(t) &
                t.revokedAt.isNull() &
                t.expiresAt.isBiggerThanValue(now),
          ))
        .write(
      SessionsCompanion(revokedAt: Value(now), lastUpdatedAt: Value(now)),
    );
  }

  Future<SessionData?> findActiveSession(String sessionId) async {
    final now = DateTime.now();
    return (select(sessions)
          ..where(
            (t) =>
                t.id.equals(sessionId) &
                whereBusiness(t) &
                t.revokedAt.isNull() &
                t.expiresAt.isBiggerThanValue(now),
          )
          ..limit(1))
        .getSingleOrNull();
  }
}

@DriftAccessor(tables: [CustomerWallets])
class CustomerWalletsDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerWalletsDaoMixin, BusinessScopedDao<AppDatabase> {
  CustomerWalletsDao(super.db);

  Future<CustomerWalletData?> getByCustomerId(String customerId) {
    return (select(customerWallets)
          ..where(
            (t) =>
                whereBusiness(t) &
                t.customerId.equals(customerId) &
                t.isDeleted.not(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> updateWalletLimit(String customerId, int limitKobo) async {
    await (update(attachedDatabase.customers)..where(
          (t) => t.id.equals(customerId) & whereBusiness(t),
        ))
        .write(
          CustomersCompanion(
            walletLimitKobo: Value(limitKobo),
            lastUpdatedAt: Value(DateTime.now()),
          ),
        );
  }
}

@DriftAccessor(tables: [WalletTransactions, CustomerWallets, PaymentTransactions, Orders])
class WalletTransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$WalletTransactionsDaoMixin, BusinessScopedDao<AppDatabase> {
  WalletTransactionsDao(super.db);

  /// Computes the current wallet balance by summing all signed amounts.
  /// Per PR 4d "Recommended void approach", we don't filter by voidedAt IS NULL
  /// because a compensating entry (opposite sign) will have been appended.
  Future<int> getBalanceKobo(String customerId) async {
    final sumExpr = walletTransactions.signedAmountKobo.sum();
    final query = selectOnly(walletTransactions)
      ..addColumns([sumExpr])
      ..where(
        whereBusiness(walletTransactions) &
            walletTransactions.customerId.equals(customerId),
      );
    final row = await query.getSingleOrNull();
    return row?.read(sumExpr) ?? 0;
  }

  Stream<int> watchBalanceKobo(String customerId) {
    final sumExpr = walletTransactions.signedAmountKobo.sum();
    final query = selectOnly(walletTransactions)
      ..addColumns([sumExpr])
      ..where(
        whereBusiness(walletTransactions) &
            walletTransactions.customerId.equals(customerId),
      );
    return query.watchSingleOrNull().map((row) => row?.read(sumExpr) ?? 0);
  }

  Stream<Map<String, int>> watchAllBalancesKobo() {
    final sumExpr = walletTransactions.signedAmountKobo.sum();
    final query = selectOnly(walletTransactions)
      ..addColumns([walletTransactions.customerId, sumExpr])
      ..where(whereBusiness(walletTransactions))
      ..groupBy([walletTransactions.customerId]);
    return query.watch().map((rows) {
      final out = <String, int>{};
      for (final r in rows) {
        final cid = r.read(walletTransactions.customerId);
        final sum = r.read(sumExpr);
        if (cid != null) out[cid] = sum ?? 0;
      }
      return out;
    });
  }

  Stream<List<WalletTransactionData>> watchHistory(String customerId) {
    return (select(walletTransactions)
          ..where(
            (t) =>
                whereBusiness(t) &
                t.customerId.equals(customerId),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Voids a transaction by marking the original as voided AND appending
  /// a compensating entry with the opposite sign.
  Future<void> voidTransaction({
    required String transactionId,
    required String voidedBy,
    required String reason,
  }) async {


    await transaction(() async {
      final original = await (select(walletTransactions)
            ..where((t) => t.id.equals(transactionId))
            ..limit(1))
          .getSingleOrNull();

      if (original == null) return;
      if (original.voidedAt != null) return; // Already voided

      // 1. Mark original as voided
      await (update(walletTransactions)..where((t) => t.id.equals(transactionId)))
          .write(
        WalletTransactionsCompanion(
          voidedAt: Value(DateTime.now()),
          voidedBy: Value(voidedBy),
          voidReason: Value(reason),
          lastUpdatedAt: Value(DateTime.now()),
        ),
      );

      // 2. Append compensating entry
      await into(walletTransactions).insert(
        WalletTransactionsCompanion.insert(
          id: Value(UuidV7.generate()),
          businessId: requireBusinessId(),
          walletId: original.walletId,
          customerId: original.customerId,
          type: original.type == 'credit' ? 'debit' : 'credit',
          amountKobo: original.amountKobo,
          signedAmountKobo: -original.signedAmountKobo,
          referenceType: 'void',
          orderId: Value(original.orderId), // Link to same order if applicable
          performedBy: Value(voidedBy),
          createdAt: Value(DateTime.now()),
          lastUpdatedAt: Value(DateTime.now()),
        ),
      );
    });
  }
}

@DriftAccessor(tables: [CrateGroups])
class CrateGroupsDao extends DatabaseAccessor<AppDatabase>
    with _$CrateGroupsDaoMixin, BusinessScopedDao<AppDatabase> {
  CrateGroupsDao(super.db);

  Stream<List<CrateGroupData>> watchAll() {
    return (select(crateGroups)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<CrateGroupData>> getAll() {
    return (select(crateGroups)
          ..where((t) => whereBusiness(t) & t.isDeleted.not())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }
}

@DriftAccessor(tables: [CustomerCrateBalances, CrateGroups])
class CustomerCrateBalancesDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerCrateBalancesDaoMixin, BusinessScopedDao<AppDatabase> {
  CustomerCrateBalancesDao(super.db);

  Stream<List<CustomerCrateBalanceWithGroup>> watchByCustomer(String customerId) {
    final query = select(customerCrateBalances).join([
      innerJoin(
        crateGroups,
        crateGroups.id.equalsExp(customerCrateBalances.crateGroupId),
      ),
    ]);
    query.where(
      whereBusiness(customerCrateBalances) &
          customerCrateBalances.customerId.equals(customerId),
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        return CustomerCrateBalanceWithGroup(
          balance: row.readTable(customerCrateBalances),
          group: row.readTable(crateGroups),
        );
      }).toList();
    });
  }
}

class CustomerCrateBalanceWithGroup {
  final CustomerCrateBalance balance;
  final CrateGroupData group;
  CustomerCrateBalanceWithGroup({required this.balance, required this.group});
}

@DriftAccessor(tables: [ManufacturerCrateBalances, CrateGroups])
class ManufacturerCrateBalancesDao extends DatabaseAccessor<AppDatabase>
    with _$ManufacturerCrateBalancesDaoMixin, BusinessScopedDao<AppDatabase> {
  ManufacturerCrateBalancesDao(super.db);

  Stream<List<ManufacturerCrateBalanceWithGroup>> watchByManufacturer(
    String manufacturerId,
  ) {
    final query = select(manufacturerCrateBalances).join([
      innerJoin(
        crateGroups,
        crateGroups.id.equalsExp(manufacturerCrateBalances.crateGroupId),
      ),
    ]);
    query.where(
      whereBusiness(manufacturerCrateBalances) &
          manufacturerCrateBalances.manufacturerId.equals(manufacturerId),
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        return ManufacturerCrateBalanceWithGroup(
          balance: row.readTable(manufacturerCrateBalances),
          group: row.readTable(crateGroups),
        );
      }).toList();
    });
  }
}

class ManufacturerCrateBalanceWithGroup {
  final ManufacturerCrateBalance balance;
  final CrateGroupData group;
  ManufacturerCrateBalanceWithGroup({required this.balance, required this.group});
}

@DriftAccessor(tables: [
  CrateLedger,
  CustomerCrateBalances,
  ManufacturerCrateBalances,
])
class CrateLedgerDao extends DatabaseAccessor<AppDatabase>
    with _$CrateLedgerDaoMixin, BusinessScopedDao<AppDatabase> {
  CrateLedgerDao(super.db);

  Future<void> recordCrateReturnByManufacturer({
    required String manufacturerId,
    required String crateGroupId,
    required int quantity,
    required String performedBy,
  }) async {
    final delta = -quantity; // returning empties reduces our balance

    await transaction(() async {
      // 1. Append crate_ledger entry
      await into(crateLedger).insert(
        CrateLedgerCompanion.insert(
          id: Value(UuidV7.generate()),
          businessId: requireBusinessId(),
          manufacturerId: Value(manufacturerId),
          crateGroupId: crateGroupId,
          quantityDelta: delta,
          movementType: 'returned',
          performedBy: Value(performedBy),
        ),
      );

      // 2. Update manufacturer_crate_balances cache
      await customStatement(
        'INSERT INTO manufacturer_crate_balances (id, business_id, manufacturer_id, crate_group_id, balance) '
        'VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(business_id, manufacturer_id, crate_group_id) DO UPDATE SET '
        'balance = balance + excluded.balance, last_updated_at = CURRENT_TIMESTAMP',
        [UuidV7.generate(), requireBusinessId(), manufacturerId, crateGroupId, delta],
      );
    });
  }

  Future<void> recordCrateReturnByCustomer({
    required String customerId,
    required String crateGroupId,
    required int quantity,
    required String performedBy,
    String? orderId,
  }) async {
    final delta = -quantity; // customer returning reduces balance

    await transaction(() async {
      await into(crateLedger).insert(
        CrateLedgerCompanion.insert(
          id: Value(UuidV7.generate()),
          businessId: requireBusinessId(),
          customerId: Value(customerId),
          manufacturerId: const Value.absent(),
          crateGroupId: crateGroupId,
          quantityDelta: delta,
          movementType: 'returned',
          referenceOrderId: Value(orderId),
          performedBy: Value(performedBy),
        ),
      );

      await customStatement(
        'INSERT INTO customer_crate_balances (id, business_id, customer_id, crate_group_id, balance) '
        'VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(business_id, customer_id, crate_group_id) DO UPDATE SET '
        'balance = balance + excluded.balance, last_updated_at = CURRENT_TIMESTAMP',
        [UuidV7.generate(), requireBusinessId(), customerId, crateGroupId, delta],
      );
    });
  }

  /// Verification logic to ensure cache tables match ledger sums.
  /// To be scheduled nightly or run on-demand.
  Future<void> verifyCrateReconciliation() async {

    // 1. Reconcile Customers
    final customerLedgerSums = await (selectOnly(crateLedger)
          ..addColumns([
            crateLedger.customerId,
            crateLedger.crateGroupId,
            crateLedger.quantityDelta.sum()
          ])
          ..where(whereBusiness(crateLedger) &
              crateLedger.customerId.isNotNull())
          ..groupBy([crateLedger.customerId, crateLedger.crateGroupId]))
        .get();

    for (final row in customerLedgerSums) {
      final custId = row.read(crateLedger.customerId)!;
      final cgId = row.read(crateLedger.crateGroupId)!;
      final sum = row.read(crateLedger.quantityDelta.sum()) ?? 0;

      final cache = await (select(customerCrateBalances)
            ..where((t) =>
                whereBusiness(t) &
                t.customerId.equals(custId) &
                t.crateGroupId.equals(cgId)))
          .getSingleOrNull();

      if (cache == null || cache.balance != sum.toInt()) {
        // Log mismatch or trigger auto-fix (logging for now)
        // ignore: avoid_print
        print(
            'CRATE MISMATCH [Customer]: $custId, Group: $cgId, Ledger: $sum, Cache: ${cache?.balance}');
      }
    }

    // 2. Reconcile Manufacturers
    final manufacturerLedgerSums = await (selectOnly(crateLedger)
          ..addColumns([
            crateLedger.manufacturerId,
            crateLedger.crateGroupId,
            crateLedger.quantityDelta.sum()
          ])
          ..where(whereBusiness(crateLedger) &
              crateLedger.manufacturerId.isNotNull())
          ..groupBy([crateLedger.manufacturerId, crateLedger.crateGroupId]))
        .get();

    for (final row in manufacturerLedgerSums) {
      final mfrId = row.read(crateLedger.manufacturerId)!;
      final cgId = row.read(crateLedger.crateGroupId)!;
      final sum = row.read(crateLedger.quantityDelta.sum()) ?? 0;

      final cache = await (select(manufacturerCrateBalances)
            ..where((t) =>
                whereBusiness(t) &
                t.manufacturerId.equals(mfrId) &
                t.crateGroupId.equals(cgId)))
          .getSingleOrNull();

      if (cache == null || cache.balance != sum.toInt()) {
        // ignore: avoid_print
        print(
            'CRATE MISMATCH [Manufacturer]: $mfrId, Group: $cgId, Ledger: $sum, Cache: ${cache?.balance}');
      }
    }
  }
}

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin, BusinessScopedDao<AppDatabase> {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(settings)
          ..where((t) => whereBusiness(t) & t.key.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await customStatement(
      'INSERT INTO settings (id, business_id, "key", value) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(business_id, "key") DO UPDATE SET value = excluded.value, last_updated_at = (strftime(\'%s\', \'now\'))',
      [UuidV7.generate(), requireBusinessId(), key, value],
    );
  }

  Stream<String?> watch(String key) {
    return (select(settings)
          ..where((t) => whereBusiness(t) & t.key.equals(key))
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  /// Helper for timezone-aware logic (PR 4c/4f)
  Future<String> getTimezone() async {
    return (await get('business_timezone')) ?? 'UTC';
  }

  Stream<String> watchTimezone() {
    return watch('business_timezone').map((v) => v ?? 'UTC');
  }
}

@DriftAccessor(tables: [SystemConfig])
class SystemConfigDao extends DatabaseAccessor<AppDatabase> with _$SystemConfigDaoMixin {
  SystemConfigDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(systemConfig)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String? value) async {
    await customStatement(
      'INSERT INTO system_config ("key", value) VALUES (?, ?) '
      'ON CONFLICT("key") DO UPDATE SET value = excluded.value, last_updated_at = (strftime(\'%s\', \'now\'))',
      [key, value],
    );
  }
}
